/* termclock - terminal clock and countdown timer drawn like the swaylock ring.
 *
 * termclock              clock with seconds
 * termclock -t [TIME]    countdown timer, asks for TIME when it is missing
 * termtimer [TIME]       same as termclock -t
 *
 * TIME: 25 (minutes), 25m, 1h30m, 90s, 10:00 (MM:SS), 1:30:00 (H:MM:SS)
 * Keys: q quits. Timer: space pauses and resumes. Alarm: any key stops it.
 * Colours come from ~/.config/swaylock/config.
 *
 * The ring is drawn with sixel graphics. The window is cut into tiles: a tile
 * whose cells each have one colour is written as coloured blank cells, any
 * other tile as a small sixel image, and a frame rewrites only the tiles whose
 * content changed. The digits are text: half-block cells. The terminal must
 * report its size in pixels.
 */
#define _GNU_SOURCE
#include <ctype.h>
#include <errno.h>
#include <fcntl.h>
#include <math.h>
#include <poll.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/wait.h>
#include <termios.h>
#include <time.h>
#include <unistd.h>

#define PUTS(s)    put(s, sizeof(s) - 1)
#define MIN(a, b)  ((a) < (b) ? (a) : (b))
#define MAX(a, b)  ((a) > (b) ? (a) : (b))
#define SOUND      "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga"
#define SOUND_SECS 180
#define NONE       0xffffffffu   /* the terminal's default background */
#define UNSET      0xfffffffeu
#define AAQ        8             /* steps of edge coverage */
#define TILEPX     64            /* tile width in pixels, about */
#define STEPS      32            /* colour steps of the timer ring */

typedef struct { double r, g, b; } Col;

static const char *usage =
	"usage: termclock [-t [TIME]]\n"
	"       termtimer [TIME]\n"
	"TIME: 25 (minutes), 25m, 1h30m, 90s, 10:00 (MM:SS), 1:30:00 (H:MM:SS)\n"
	"keys: q quit, space pause/resume (timer), any key stops the alarm\n";

static struct { const char *key; char val[128]; } conf[] = {
	{ "color",            "000000" },
	{ "ring-color",       "99d8fecc" },
	{ "inside-color",     "000000cc" },
	{ "text-color",       "e8e8e8" },
	{ "ring-ver-color",   "30f7be" },
	{ "ring-wrong-color", "da3030" },
	{ "key-hl-color",     "30f7be" },
	{ "datestr",          "%d %b %Y, %a" },
};
enum { CBG, CRING, CINSIDE, CTEXT, CVER, CWRONG, CKEYHL, CDATE, NCONF };
static Col col[CDATE];
static const Col amber = { 240, 176, 48 };

/* digits 0-9 and ':' (index 10) */
#define FONTH 5
static const char *font[11][FONTH] = {
	{ "###", "#.#", "#.#", "#.#", "###" },
	{ ".#.", "##.", ".#.", ".#.", "###" },
	{ "###", "..#", "###", "#..", "###" },
	{ "###", "..#", ".##", "..#", "###" },
	{ "#.#", "#.#", "###", "..#", "..#" },
	{ "###", "#..", "###", "..#", "###" },
	{ "###", "#..", "###", "#.#", "###" },
	{ "###", "..#", "..#", "..#", "..#" },
	{ "###", "#.#", "###", "#.#", "###" },
	{ "###", "#.#", "###", "..#", "###" },
	{ ".", "#", ".", "#", "." },
};

/* where a cell lies: outside the ring, inside it, within the band, on a circle */
enum { OUT, IN, BAND, EDGE };
/* how the arc covers a cell */
enum { ARC_NO, ARC_ALL, ARC_SOME };
/* sixel palette: inside, the ring between ringB and ringA, edge blends */
enum { P_NONE, P_INSIDE, P_RING, P_INNER = P_RING + AAQ + 1,
       P_OUTER = P_INNER + (AAQ - 1) * (AAQ + 1), P_END = P_OUTER + (AAQ - 1) * (AAQ + 1) };

static volatile sig_atomic_t quit, resized;
static struct termios oldtio;
static sigset_t origmask;

/* cells in pixels; tiles of tr x tc cells cover rows off .. off + ntr * tr */
static int cols, rows, cw, ch, plain, cleared, off, tr, tc, ntr, ntc;
static double CX, CY, R, r;
static unsigned char *cls, *tileimg, *pix;
static uint64_t *tilesig;

/* ring colour: ringA on the arc, ringB elsewhere */
static Col ringA, ringB, pal[P_END];
static double arc0, arclen, arcx0, arcy0, arcx1, arcy1;

/* big digits, none when dk is 0: font pixels of dk cells by dk half rows from
 * cell column dc0 and half row dh0, dw cells wide and dh half rows high; up to
 * two rows of text */
static int dk, dc0, dh0, dw, dh, *dmap;
static int nt, trow[2], tcol[2], tlen[2];
static const char *tstr[2];

/* output buffer, terminal cursor and colours, and the text cells on screen */
static char *buf;
static size_t blen, bcap;
static uint32_t *lastch, *lastfg, *lastbg, curfg, curbg;
static int cury, curx;

/* sixel encoder: the run-length coded line of each colour in the current band */
static struct line { char *s; size_t len, cap; int next, n, used; char c; } lines[P_END];
static unsigned char used[P_END];

static double
clamp(double v)
{
	return v < 0 ? 0 : v > 1 ? 1 : v;
}

static Col
lerp(Col a, Col b, double t)
{
	return (Col){ a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t };
}

/* the colour as sixel keeps it: whole percents */
static Col
pq(Col c)
{
	return (Col){ lround(c.r * 100 / 255) * 2.55, lround(c.g * 100 / 255) * 2.55,
	              lround(c.b * 100 / 255) * 2.55 };
}

static uint32_t
pack(Col c)
{
	return (uint32_t)lround(c.r) << 16 | (uint32_t)lround(c.g) << 8 | (uint32_t)lround(c.b);
}

static uint64_t
mix(uint64_t h, uint64_t v)
{
	return h ^ (v + 0x9e3779b97f4a7c15ull + (h << 6) + (h >> 2));
}

static uint64_t
dbits(double d)
{
	uint64_t u;

	memcpy(&u, &d, sizeof u);
	return u;
}

static int
hexval(int c)
{
	return isdigit(c) ? c - '0' : isxdigit(c) ? tolower(c) - 'a' + 10 : -1;
}

static int
parsecol(const char *s, Col *c, double *a)
{
	int v[8], n = 0;

	if (*s == '#')
		s++;
	for (; s[n] && n < 8; n++)
		if ((v[n] = hexval((unsigned char)s[n])) < 0)
			return -1;
	if ((n != 6 && n != 8) || s[n])
		return -1;
	c->r = v[0] * 16 + v[1];
	c->g = v[2] * 16 + v[3];
	c->b = v[4] * 16 + v[5];
	*a = n == 8 ? (v[6] * 16 + v[7]) / 255.0 : 1;
	return 0;
}

static void
loadconf(void)
{
	char path[4096], line[512], *k, *v, *e;
	const char *xdg = getenv("XDG_CONFIG_HOME"), *home = getenv("HOME");
	FILE *f;
	Col c;
	double a;
	int i;

	if (xdg && *xdg)
		snprintf(path, sizeof path, "%s/swaylock/config", xdg);
	else
		snprintf(path, sizeof path, "%s/.config/swaylock/config", home ? home : "");
	if ((f = fopen(path, "r"))) {
		while (fgets(line, sizeof line, f)) {
			if (!(v = strchr(line, '=')))
				continue;
			*v++ = '\0';
			for (k = line; isspace((unsigned char)*k); k++);
			for (e = v - 2; e >= k && isspace((unsigned char)*e); *e-- = '\0');
			for (; isspace((unsigned char)*v); v++);
			for (e = v + strlen(v) - 1; e >= v && isspace((unsigned char)*e); *e-- = '\0');
			for (i = 0; i < NCONF; i++)
				if (!strcmp(k, conf[i].key) && strlen(v) < sizeof conf[i].val)
					strcpy(conf[i].val, v);
		}
		fclose(f);
	}
	parsecol("000000", &col[CBG], &a);
	for (i = 0; i < CDATE; i++)
		if (parsecol(conf[i].val, &c, &a) == 0)
			col[i] = i == CBG ? c : lerp(col[CBG], c, a);
	for (i = 0; i < CDATE; i++)
		col[i] = pq(col[i]);
}

static void
put(const char *s, size_t n)
{
	size_t c;
	char *nb;

	if (blen + n > bcap) {
		for (c = bcap ? bcap : 65536; c < blen + n; c *= 2);
		if (!(nb = realloc(buf, c)))
			return;
		buf = nb;
		bcap = c;
	}
	memcpy(buf + blen, s, n);
	blen += n;
}

static void
putf(const char *fmt, int a, int b)
{
	char s[64];

	put(s, snprintf(s, sizeof s, fmt, a, b));
}

static void
flush(void)
{
	size_t off = 0;
	ssize_t n;

	while (off < blen) {
		if ((n = write(STDOUT_FILENO, buf + off, blen - off)) < 0) {
			if (errno == EINTR)
				continue;
			break;
		}
		off += n;
	}
	blen = 0;
}

static void
sgr(int ground, uint32_t c)
{
	char s[32];
	int n;

	if (c == NONE)
		n = snprintf(s, sizeof s, "\33[%dm", ground + 1);
	else
		n = snprintf(s, sizeof s, "\33[%d;2;%u;%u;%um", ground,
		             c >> 16, c >> 8 & 255, c & 255);
	put(s, n);
}

/* write codepoint c in cell (y, x) unless the cell already shows it */
static void
emit(int y, int x, int c, uint32_t f, uint32_t b)
{
	size_t i = (size_t)y * cols + x;
	char s[3] = { c < 0x80 ? c : 0xe0 | c >> 12, 0x80 | (c >> 6 & 63), 0x80 | (c & 63) };

	if (c == ' ')
		f = UNSET;
	if (lastch[i] == (uint32_t)c && lastfg[i] == f && lastbg[i] == b)
		return;
	lastch[i] = c;
	lastfg[i] = f;
	lastbg[i] = b;
	if (y != cury || x != curx)
		putf("\33[%d;%dH", y + 1, x + 1);
	if (f != UNSET && f != curfg)
		sgr(38, curfg = f);
	if (b != curbg)
		sgr(48, curbg = b);
	put(s, c < 0x80 ? 1 : 3);
	cury = y;
	curx = x + 1 < cols ? x + 1 : -1;
}

/* half width of the inside circle at pixel row y */
static double
chord(double y)
{
	double dy = fabs(y - CY) + 1;

	return dy < r ? sqrt(r * r - dy * dy) - 1 : 0;
}

static int
glyph(char c)
{
	return c == ':' ? 10 : c - '0';
}

static int
textwidth(const char *s)
{
	int w = 0, n = 0;

	for (; *s; s++, n++)
		w += strlen(font[glyph(*s)][0]);
	return w + n - 1;
}

static void
geometry(void)
{
	struct winsize ws = { 0 };
	double x0, y0, nx, ny, fx, fy, near, far, H;
	size_t n;
	int x, y, g;

	if (ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) < 0 || !ws.ws_col || !ws.ws_row) {
		ws.ws_col = 80;
		ws.ws_row = 24;
	}
	cols = ws.ws_col;
	rows = ws.ws_row;
	cw = ws.ws_xpixel / cols;
	ch = ws.ws_ypixel / rows;
	/* sixel images grow in bands of 6 pixels: a tile is as many cell rows as
	 * make a multiple of 6, so that no image reaches into the next row */
	for (g = 6; ch % g || 6 % g; g--);
	tr = 6 / g;
	tc = MAX(1, MIN((TILEPX + cw / 2) / MAX(cw, 1), 64 / tr));
	ntr = rows / tr;
	off = rows % tr / 2;
	ntc = (cols + tc - 1) / tc;
	H = (double)ntr * tr * ch;
	CX = cols * cw / 2.0;
	CY = off * ch + H / 2;
	R = (fmin(cols * cw, H) - 2) / 2;
	r = R - fmax(2, round(R * 0.1));
	plain = !cw || !ch || r < 8;

	n = (size_t)cols * rows;
	if (!(cls = realloc(cls, n)) ||
	    !(lastch = realloc(lastch, n * sizeof *lastch)) ||
	    !(lastfg = realloc(lastfg, n * sizeof *lastfg)) ||
	    !(lastbg = realloc(lastbg, n * sizeof *lastbg)) ||
	    !(tilesig = realloc(tilesig, ((size_t)ntr * ntc + 1) * sizeof *tilesig)) ||
	    !(tileimg = realloc(tileimg, (size_t)ntr * ntc + 1)) ||
	    !(pix = realloc(pix, (size_t)tr * ch * tc * cw + 1)) ||
	    !(dmap = realloc(dmap, ((size_t)cols + 1) * sizeof *dmap)))
		exit(1);
	for (y = 0; y < rows; y++)
		for (x = 0; x < cols; x++) {
			x0 = x * cw - CX;
			y0 = y * ch - CY;
			nx = x0 > 0 ? x0 : x0 + cw < 0 ? -(x0 + cw) : 0;
			ny = y0 > 0 ? y0 : y0 + ch < 0 ? -(y0 + ch) : 0;
			fx = fmax(fabs(x0), fabs(x0 + cw));
			fy = fmax(fabs(y0), fabs(y0 + ch));
			near = hypot(nx, ny);
			far = hypot(fx, fy);
			cls[(size_t)y * cols + x] = plain || y < off || y >= off + ntr * tr || near >= R + 0.5 ? OUT :
			                            far <= r - 0.5 ? IN :
			                            near >= r + 0.5 && far <= R - 0.5 ? BAND : EDGE;
		}
	cleared = 0;
}

static void
textrow(int row, const char *s, int inside)
{
	int len = strlen(s);

	if (!len || len > cols || row < 0 || row >= rows || nt >= 2)
		return;
	if (inside && len * cw / 2.0 > fmin(chord(row * ch), chord((row + 1) * ch)))
		return;
	trow[nt] = row;
	tcol[nt] = (int)lround((cols - len) / 2.0);
	tstr[nt] = s;
	tlen[nt] = len;
	nt++;
}

static void
layout(const char *big, const char *small)
{
	double hh = ch / 2.0, gap;
	int x, gx, sx, w;
	const char *p;

	dk = 0;
	nt = 0;
	if (plain) {
		textrow(rows / 2 - 1, big, 0);
		textrow(rows / 2, small, 0);
		return;
	}
	/* a font pixel is dk cells wide and dk half rows high, about square */
	dk = (int)fmin(2 * r * 0.78 / cw / textwidth(big), 2 * r * 0.40 / hh / FONTH);
	if (!dk) {
		textrow((int)(CY / ch) - 1, big, 1);
		textrow((int)(CY / ch), small, 1);
		if (!nt) {
			/* not even plain text fits inside: show the text without the ring */
			plain = 1;
			cleared = 0;
			layout(big, small);
		}
		return;
	}
	dw = textwidth(big) * dk;
	dh = FONTH * dk;
	gap = fmax(2, dh / 4.0);
	dh0 = (int)lround(CY / hh - (dh + gap + 2) / 2);
	dc0 = (int)lround((cols - dw) / 2.0);
	for (x = 0, p = big; *p; p++) {
		w = strlen(font[glyph(*p)][0]);
		for (gx = 0; gx < w; gx++)
			for (sx = 0; sx < dk; sx++)
				dmap[x++] = glyph(*p) << 3 | gx;
		if (p[1])
			for (sx = 0; sx < dk; sx++)
				dmap[x++] = -1;
	}
	textrow((int)ceil((dh0 + dh + gap) / 2.0), small, 1);
}

/* whether the font pixel at cell column x, half row hr is lit */
static int
dbit(int x, int hr)
{
	int m;

	if (!dk || x < dc0 || x >= dc0 + dw || hr < dh0 || hr >= dh0 + dh || (m = dmap[x - dc0]) < 0)
		return 0;
	return font[m >> 3][(hr - dh0) / dk][m & 7] == '#';
}

/* whether cell (y, x) is text: the digits or a text row */
static int
istext(int y, int x)
{
	int k;

	if (dk && x >= dc0 && x < dc0 + dw && 2 * y + 1 >= dh0 && 2 * y < dh0 + dh)
		return 1;
	for (k = 0; k < nt; k++)
		if (y == trow[k] && x >= tcol[k] && x < tcol[k] + tlen[k])
			return 1;
	return 0;
}

static void
setarc(double start, double len)
{
	arc0 = start;
	arclen = len;
	arcx0 = sin(2 * M_PI * start);
	arcy0 = -cos(2 * M_PI * start);
	arcx1 = sin(2 * M_PI * (start + len));
	arcy1 = -cos(2 * M_PI * (start + len));
}

/* how much of the pixel at (px, py) from the centre lies on the arc */
static double
arccov(double px, double py)
{
	double c0, c1;

	if (arclen >= 1)
		return 1;
	if (arclen <= 0)
		return 0;
	c0 = arcx0 * py - arcy0 * px;
	c1 = px * arcy1 - py * arcx1;
	return clamp((arclen <= 0.5 ? fmin(c0, c1) : fmax(c0, c1)) + 0.5);
}

/* how the arc covers the box (x0, y0)-(x1, y1) from the centre; *b0 and *b1 tell
 * whether its pixels depend on the start and on the end of the arc */
static int
boxarc(double x0, double y0, double x1, double y1, int *b0, int *b1)
{
	const double xs[4] = { x0, x1, x0, x1 }, ys[4] = { y0, y0, y1, y1 };
	double c0, c1, lo0 = HUGE_VAL, hi0 = -HUGE_VAL, lo1 = HUGE_VAL, hi1 = -HUGE_VAL;
	int i;

	*b0 = *b1 = 0;
	if (arclen >= 1)
		return ARC_ALL;
	if (arclen <= 0)
		return ARC_NO;
	for (i = 0; i < 4; i++) {
		c0 = arcx0 * ys[i] - arcy0 * xs[i];
		c1 = xs[i] * arcy1 - ys[i] * arcx1;
		lo0 = fmin(lo0, c0);
		hi0 = fmax(hi0, c0);
		lo1 = fmin(lo1, c1);
		hi1 = fmax(hi1, c1);
	}
	if (arclen <= 0.5) {
		if (lo0 >= 0.5 && lo1 >= 0.5)
			return ARC_ALL;
		if (hi0 <= -0.5 || hi1 <= -0.5)
			return ARC_NO;
		*b0 = lo0 < 0.5;
		*b1 = lo1 < 0.5;
	} else {
		if (lo0 >= 0.5 || lo1 >= 0.5)
			return ARC_ALL;
		if (hi0 <= -0.5 && hi1 <= -0.5)
			return ARC_NO;
		*b0 = hi0 > -0.5;
		*b1 = hi1 > -0.5;
	}
	return ARC_SOME;
}

/* what cell (y, x) shows: 1 and its colour in *c when it has one colour,
 * else 0 and a signature of its pixels in *sig */
static int
celldesc(int y, int x, uint32_t *c, uint64_t *sig)
{
	double x0 = x * cw - CX, y0 = y * ch - CY;
	uint64_t h;
	int k = cls[(size_t)y * cols + x], a, b0, b1;

	if (k == OUT || k == IN) {
		*c = k == OUT ? NONE : pack(col[CINSIDE]);
		return 1;
	}
	a = boxarc(x0, y0, x0 + cw, y0 + ch, &b0, &b1);
	if (a != ARC_SOME) {
		*c = pack(a == ARC_ALL ? ringA : ringB);
		if (k == BAND)
			return 1;
		*sig = mix(k, *c);
		return 0;
	}
	h = mix(mix(mix(k, pack(ringA)), pack(ringB)), b0 ? dbits(arc0) : 1);
	h = mix(h, b1 ? dbits(arc0 + arclen) : 1);
	*sig = mix(h, b0 && b1 && arclen > 0.5);
	return 0;
}

static void
palette(void)
{
	Col q[AAQ + 1];
	int j, k;

	pal[P_INSIDE] = col[CINSIDE];
	for (k = 0; k <= AAQ; k++)
		pal[P_RING + k] = q[k] = pq(lerp(ringB, ringA, (double)k / AAQ));
	for (j = 1; j < AAQ; j++)
		for (k = 0; k <= AAQ; k++) {
			pal[P_INNER + (j - 1) * (AAQ + 1) + k] = pq(lerp(q[k], col[CINSIDE], (double)j / AAQ));
			pal[P_OUTER + (j - 1) * (AAQ + 1) + k] = pq(lerp(col[CBG], q[k], (double)j / AAQ));
		}
}

/* palette index of a pixel at (px, py) from the centre near a circle */
static int
edgeidx(double px, double py)
{
	double d = hypot(px, py);
	int o = (int)lround(clamp(R - d + 0.5) * AAQ), in = (int)lround(clamp(r - d + 0.5) * AAQ);
	int q = (int)lround(arccov(px, py) * AAQ);

	if (o <= 0)
		return P_NONE;
	if (in >= AAQ)
		return P_INSIDE;
	if (in > 0)
		return P_INNER + (in - 1) * (AAQ + 1) + q;
	if (o < AAQ)
		return P_OUTER + (o - 1) * (AAQ + 1) + q;
	return P_RING + q;
}

static void
lput(struct line *l, const char *s, size_t n)
{
	size_t c;
	char *nb;

	if (l->len + n > l->cap) {
		for (c = l->cap ? l->cap : 256; c < l->len + n; c *= 2);
		if (!(nb = realloc(l->s, c)))
			return;
		l->s = nb;
		l->cap = c;
	}
	memcpy(l->s + l->len, s, n);
	l->len += n;
}

static void
lflush(struct line *l)
{
	char t[16];
	int i;

	if (l->n > 3)
		lput(l, t, snprintf(t, sizeof t, "!%d%c", l->n, l->c));
	else
		for (i = 0; i < l->n; i++)
			lput(l, &l->c, 1);
	l->n = 0;
}

/* add sixel c at column x to the line */
static void
lsix(struct line *l, int x, char c)
{
	if (x > l->next) {
		lflush(l);
		l->c = '?';
		l->n = x - l->next;
	}
	if (!l->n || l->c != c) {
		lflush(l);
		l->c = c;
	}
	l->n++;
	l->next = x + 1;
}

/* draw the tile at cell (r0, c0), nc cells wide, as a sixel image */
static void
drawtile(int r0, int c0, int nc)
{
	int w = nc * cw, h = tr * ch, px0 = c0 * cw, py0 = r0 * ch, x, y, k, j, i, mask, bh;
	int lu[P_END], nl;
	double py, dy2, xo, xs, xio, xi, px, ax;
	unsigned char *row, v[6];
	struct line *l;
	char t[48];

	memset(used, 0, sizeof used);
	for (y = 0; y < h; y++) {
		row = pix + (size_t)y * w;
		memset(row, P_NONE, w);
		py = py0 + y + 0.5 - CY;
		if (fabs(py) < R + 0.5) {
			dy2 = py * py;
			xo = sqrt((R + 0.5) * (R + 0.5) - dy2);
			xs = (R - 0.5) * (R - 0.5) > dy2 ? sqrt((R - 0.5) * (R - 0.5) - dy2) : -1;
			xio = (r + 0.5) * (r + 0.5) > dy2 ? sqrt((r + 0.5) * (r + 0.5) - dy2) : -1;
			xi = (r - 0.5) * (r - 0.5) > dy2 ? sqrt((r - 0.5) * (r - 0.5) - dy2) : -1;
			for (x = 0; x < w; x++) {
				px = px0 + x + 0.5 - CX;
				ax = fabs(px);
				if (ax < xi)
					row[x] = P_INSIDE;
				else if (ax >= xio && ax < xs)
					row[x] = P_RING + (int)lround(arccov(px, py) * AAQ);
				else if (ax < xo)
					row[x] = edgeidx(px, py);
			}
		}
		/* text cells stay transparent: their characters show through */
		for (k = 0; k < nc; k++)
			if (istext(r0 + y / ch, c0 + k))
				memset(row + k * cw, P_NONE, cw);
		for (x = 0; x < w; x++)
			used[row[x]] = 1;
	}

	putf("\33[%d;%dH", r0 + 1, c0 + 1);
	putf("\33P0;1;0q\"1;1;%d;%d", w, h);
	for (i = 1; i < P_END; i++)
		if (used[i])
			put(t, snprintf(t, sizeof t, "#%d;2;%ld;%ld;%ld", i, lround(pal[i].r * 100 / 255),
			                lround(pal[i].g * 100 / 255), lround(pal[i].b * 100 / 255)));
	for (y = 0; y < h; y += 6) {
		bh = MIN(6, h - y);
		nl = 0;
		for (x = 0; x < w; x++) {
			for (k = 0; k < bh; k++)
				v[k] = pix[(size_t)(y + k) * w + x];
			for (k = 0; k < bh; k++) {
				if (!(i = v[k]))
					continue;
				for (j = k, mask = 0; j < bh; j++)
					if (v[j] == i) {
						mask |= 1 << j;
						v[j] = 0;
					}
				l = &lines[i];
				if (!l->used) {
					l->used = 1;
					l->len = 0;
					l->next = 0;
					l->n = 0;
					lu[nl++] = i;
				}
				lsix(l, x, 63 + mask);
			}
		}
		for (k = 0; k < nl; k++) {
			l = &lines[lu[k]];
			lflush(l);
			put(t, snprintf(t, sizeof t, k ? "$#%d" : "#%d", lu[k]));
			put(l->s, l->len);
			l->used = 0;
		}
		if (y + 6 < h)
			PUTS("-");
	}
	PUTS("\33\\");
	cury = curx = -1;
}

static void
frame(const char *big, const char *small)
{
	uint32_t c[64];
	uint64_t h, s;
	size_t i, n = (size_t)cols * rows;
	int ti, tj, t, x, y, k, img, r0, c0, nc, top, bot;

	layout(big, small);
	curfg = curbg = UNSET;
	cury = curx = -1;
	PUTS("\33[?2026h\33[0m");
	if (!cleared) {
		PUTS("\33[2J");
		for (i = 0; i < n; i++) {
			lastch[i] = ' ';
			lastfg[i] = UNSET;
			lastbg[i] = NONE;
		}
		memset(tilesig, 0, ((size_t)ntr * ntc + 1) * sizeof *tilesig);
		memset(tileimg, 0, (size_t)ntr * ntc + 1);
		cleared = 1;
	}
	if (!plain) {
		palette();
		for (ti = 0; ti < ntr; ti++)
			for (tj = 0; tj < ntc; tj++) {
				t = ti * ntc + tj;
				r0 = off + ti * tr;
				c0 = tj * tc;
				nc = MIN(tc, cols - c0);
				h = 1;
				img = 0;
				for (y = r0, k = 0; y < r0 + tr; y++)
					for (x = c0; x < c0 + nc; x++, k++) {
						if (istext(y, x)) {
							c[k] = UNSET;
							h = mix(h, 3);
						} else if (celldesc(y, x, &c[k], &s)) {
							h = mix(mix(h, 1), c[k]);
						} else {
							c[k] = UNSET;
							img = 1;
							h = mix(mix(h, 2), s);
						}
					}
				if (h == tilesig[t] && img == tileimg[t])
					continue;
				if (img)
					drawtile(r0, c0, nc);
				for (y = r0, k = 0; y < r0 + tr; y++)
					for (x = c0; x < c0 + nc; x++, k++) {
						if (c[k] == UNSET)
							continue;
						/* a cell under an image is written again when it leaves it */
						if (img || tileimg[t])
							lastch[(size_t)y * cols + x] = 0;
						if (!img)
							emit(y, x, ' ', UNSET, c[k]);
					}
				tilesig[t] = h;
				tileimg[t] = img;
			}
	}
	if (plain)
		for (y = 0; y < rows; y++)
			for (x = 0; x < cols; x++)
				if (!istext(y, x))
					emit(y, x, ' ', UNSET, NONE);
	if (dk)
		for (y = dh0 / 2; 2 * y < dh0 + dh; y++)
			for (x = dc0; x < dc0 + dw; x++) {
				top = dbit(x, 2 * y);
				bot = dbit(x, 2 * y + 1);
				if (top == bot)
					emit(y, x, ' ', UNSET, pack(top ? col[CTEXT] : col[CINSIDE]));
				else
					emit(y, x, top ? 0x2580 : 0x2584, pack(col[CTEXT]), pack(col[CINSIDE]));
			}
	for (k = 0; k < nt; k++)
		for (x = tcol[k]; x < tcol[k] + tlen[k]; x++)
			emit(trow[k], x, (unsigned char)tstr[k][x - tcol[k]], pack(col[CTEXT]),
			     plain ? NONE : pack(col[CINSIDE]));
	PUTS("\33[0m\33[?2026l");
	flush();
}

static Col
gradient(double f)
{
	const double at[] = { 1.0, 0.6, 0.3, 0.0 };
	const Col c[] = { col[CRING], col[CVER], amber, col[CWRONG] };
	int i;

	for (i = 0; i < 3; i++)
		if (f >= at[i + 1])
			return pq(lerp(c[i + 1], c[i], (f - at[i + 1]) / (at[i] - at[i + 1])));
	return c[3];
}

/* seconds, or -1 */
static double
parsedur(const char *in)
{
	char s[64], *e;
	const char *u = "hms";
	double v, secs = 0;
	int n = 0, part, parts;

	for (; *in && n < (int)sizeof s - 1; in++)
		if (!isspace((unsigned char)*in))
			s[n++] = tolower((unsigned char)*in);
	s[n] = '\0';
	if (!n)
		return -1;
	if (strspn(s, "0123456789.") == (size_t)n) {
		v = strtod(s, &e);
		secs = *e ? -1 : v * 60;
	} else if (strchr(s, ':')) {
		for (e = s, parts = 0; *e; parts++) {
			n = strspn(e, "0123456789");
			if (!n || (parts && n > 2) || (e[n] && e[n] != ':'))
				return -1;
			part = atoi(e);
			secs = secs * 60 + part;
			e += n + (e[n] == ':');
			if (e[-1] == ':' && !*e)
				return -1;
		}
		if (parts < 2 || parts > 3)
			return -1;
	} else {
		for (e = s; *e;) {
			n = strspn(e, "0123456789");
			if (!n || !e[n] || !(u = strchr(u, e[n])))
				return -1;
			part = atoi(e);
			secs += part * (*u == 'h' ? 3600 : *u == 'm' ? 60 : 1);
			e += n + 1;
			u++;
		}
	}
	return secs > 0 ? secs : -1;
}

static double
askdur(void)
{
	char line[256];
	double d;

	for (;;) {
		fputs("Duration (e.g. 25m, 1h30m, 90s, 10:00): ", stdout);
		fflush(stdout);
		if (!fgets(line, sizeof line, stdin)) {
			putchar('\n');
			exit(0);
		}
		line[strcspn(line, "\n")] = '\0';
		if ((d = parsedur(line)) > 0)
			return d;
		printf("Not a valid duration: '%s'\n", line);
	}
}

static void
fmtclock(char *s, size_t n, long secs)
{
	if (secs >= 3600)
		snprintf(s, n, "%ld:%02ld:%02ld", secs / 3600, secs / 60 % 60, secs % 60);
	else
		snprintf(s, n, "%02ld:%02ld", secs / 60, secs % 60);
}

static void
fmttotal(char *s, size_t n, double total)
{
	long t = lround(total), v[3] = { t / 3600, t / 60 % 60, t % 60 };
	const char *u = "hms";
	size_t len = 0;
	int i;

	s[0] = '\0';
	for (i = 0; i < 3; i++)
		if (v[i] && len < n)
			len += snprintf(s + len, n - len, "%s%ld%c", len ? " " : "", v[i], u[i]);
}

static double
now(clockid_t id)
{
	struct timespec ts;

	clock_gettime(id, &ts);
	return ts.tv_sec + ts.tv_nsec / 1e9;
}

static pid_t
spawn(const char *a, const char *b, char *const argv[])
{
	pid_t pid = fork();
	int fd;

	if (pid)
		return pid;
	sigprocmask(SIG_SETMASK, &origmask, NULL);
	setsid();
	if ((fd = open("/dev/null", O_RDWR)) >= 0) {
		dup2(fd, 0);
		dup2(fd, 1);
		dup2(fd, 2);
	}
	execvp(a, argv);
	if (b)
		execvp(b, argv);
	_exit(127);
}

static void
onsig(int sig)
{
	if (sig == SIGWINCH)
		resized = 1;
	else
		quit = 1;
}

static void
run(double total)
{
	char big[32], small[160], label[32], tmp[16];
	char *const playargv[] = { "paplay", SOUND, NULL };
	enum { CLOCK, TIMER, ALARM } mode = total > 0 ? TIMER : CLOCK;
	struct termios tio;
	struct sigaction sa = { 0 };
	struct pollfd pfd = { STDIN_FILENO, POLLIN, 0 };
	struct timespec ts;
	struct tm tm;
	sigset_t block;
	double deadline = now(CLOCK_MONOTONIC) + total, paused = -1, rem, t, alarmat = 0, bell = 0, wait;
	pid_t player = 0, pid;
	int sound = access(SOUND, R_OK) == 0, status, i;
	ssize_t nr;
	time_t tt;

	fmttotal(label, sizeof label, total);
	sa.sa_handler = onsig;
	sigemptyset(&sa.sa_mask);
	sigaction(SIGWINCH, &sa, NULL);
	sigaction(SIGINT, &sa, NULL);
	sigaction(SIGTERM, &sa, NULL);
	sigaction(SIGHUP, &sa, NULL);
	sigemptyset(&block);
	sigaddset(&block, SIGWINCH);
	sigaddset(&block, SIGINT);
	sigaddset(&block, SIGTERM);
	sigaddset(&block, SIGHUP);
	sigprocmask(SIG_BLOCK, &block, &origmask);

	tcgetattr(STDIN_FILENO, &oldtio);
	tio = oldtio;
	tio.c_lflag &= ~(ICANON | ECHO);
	tio.c_cc[VMIN] = 1;
	tio.c_cc[VTIME] = 0;
	tcsetattr(STDIN_FILENO, TCSAFLUSH, &tio);
	PUTS("\33[?1049h\33[?25l");
	flush();
	resized = 1;

	while (!quit) {
		if (resized) {
			resized = 0;
			geometry();
		}
		while ((pid = waitpid(-1, &status, WNOHANG)) > 0)
			if (pid == player) {
				player = 0;
				if (WIFEXITED(status) && WEXITSTATUS(status) == 127)
					sound = 0;
			}

		if (mode == CLOCK) {
			t = now(CLOCK_REALTIME);
			tt = (time_t)t;
			localtime_r(&tt, &tm);
			strftime(big, sizeof big, "%H:%M:%S", &tm);
			if (!strftime(small, sizeof small, conf[CDATE].val, &tm))
				small[0] = '\0';
			ringA = col[CKEYHL];
			ringB = col[CRING];
			setarc(tm.tm_sec / 60.0 - 1.0 / 24, 1.0 / 12);
			wait = 1 - fmod(t, 1) + 0.005;
		} else if (mode == TIMER) {
			rem = paused >= 0 ? paused : deadline - now(CLOCK_MONOTONIC);
			if (rem <= 0) {
				char *const nargv[] = { "notify-send", "-u", "critical", "-a", "Timer",
				                        "Time's up", small, NULL };
				snprintf(small, sizeof small, "%s timer finished", label);
				spawn("notify-send", NULL, nargv);
				mode = ALARM;
				alarmat = now(CLOCK_MONOTONIC);
				continue;
			}
			/* the colour moves in steps, so that the whole ring is redrawn only now and then */
			ringA = gradient(ceil(rem / total * STEPS) / STEPS);
			ringB = pq(lerp(col[CINSIDE], ringA, 0.3));
			setarc(0, rem / total);
			fmtclock(big, sizeof big, (long)ceil(rem));
			if (paused >= 0) {
				snprintf(small, sizeof small, "%s, paused", label);
				wait = -1;
			} else {
				tt = time(NULL) + (time_t)ceil(rem);
				localtime_r(&tt, &tm);
				strftime(tmp, sizeof tmp, "%H:%M", &tm);
				snprintf(small, sizeof small, "%s, ends %s", label, tmp);
				wait = fmod(rem, 1) + 0.005;
			}
		} else {
			t = now(CLOCK_MONOTONIC) - alarmat;
			if (t < SOUND_SECS) {
				if (sound && !player)
					player = spawn("paplay", "pw-play", playargv);
				else if (!sound && t - bell >= 1) {
					PUTS("\a");
					bell = t;
				}
			}
			ringA = ringB = col[CWRONG];
			setarc(0, 1);
			strcpy(big, "00:00");
			strcpy(small, (long)t % 2 ? "" : "time's up, press any key");
			wait = 1 - fmod(t, 1) + 0.005;
		}

		frame(big, small);

		ts.tv_sec = (time_t)wait;
		ts.tv_nsec = (long)((wait - ts.tv_sec) * 1e9);
		if (ppoll(&pfd, 1, wait < 0 ? NULL : &ts, &origmask) > 0 && pfd.revents & POLLIN) {
			if ((nr = read(STDIN_FILENO, tmp, sizeof tmp)) <= 0 || mode == ALARM)
				break;
			for (i = 0; i < nr; i++) {
				if (tmp[i] == 'q' || tmp[i] == 'Q')
					quit = 1;
				else if (tmp[i] == ' ' && mode == TIMER) {
					if (paused < 0) {
						paused = deadline - now(CLOCK_MONOTONIC);
					} else {
						deadline = now(CLOCK_MONOTONIC) + paused;
						paused = -1;
					}
				}
			}
		}
	}

	if (player)
		kill(player, SIGTERM);
	tcsetattr(STDIN_FILENO, TCSAFLUSH, &oldtio);
	PUTS("\33[0m\33[2J\33[?25h\33[?1049l");
	flush();
}

int
main(int argc, char *argv[])
{
	const char *name = strrchr(argv[0], '/') ? strrchr(argv[0], '/') + 1 : argv[0];
	char arg[256] = "";
	int timer = !strncmp(name, "termtimer", 9), i = 1;
	double total = 0;

	if (argc > 1 && (!strcmp(argv[1], "-h") || !strcmp(argv[1], "--help"))) {
		fputs(usage, stdout);
		return 0;
	}
	if (argc > 1 && (!strcmp(argv[1], "-t") || !strcmp(argv[1], "--timer")))
		timer = 1, i = 2;
	if (!isatty(STDIN_FILENO) || !isatty(STDOUT_FILENO)) {
		fputs("termclock: needs a terminal\n", stderr);
		return 1;
	}
	if (!timer && i < argc) {
		fprintf(stderr, "termclock: unknown option: %s\n%s", argv[i], usage);
		return 1;
	}
	if (timer) {
		for (; i < argc; i++) {
			strncat(arg, argv[i], sizeof arg - strlen(arg) - 2);
			strcat(arg, " ");
		}
		if (*arg) {
			if ((total = parsedur(arg)) <= 0) {
				fprintf(stderr, "termclock: not a valid duration: %s\n", arg);
				return 1;
			}
		} else {
			total = askdur();
		}
	}
	loadconf();
	run(total);
	return 0;
}
