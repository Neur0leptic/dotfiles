/* termclock - terminal clock and countdown timer drawn like the swaylock ring.
 *
 * termclock              clock with seconds
 * termclock -t [TIME]    countdown timer, asks for TIME when it is missing
 * termtimer [TIME]       same as termclock -t
 *
 * TIME: 25 (minutes), 25m, 1h30m, 90s, 10:00 (MM:SS), 1:30:00 (H:MM:SS)
 * Keys: q quits. Timer: space pauses and resumes. Alarm: any key stops it.
 * Colours come from ~/.config/swaylock/config.
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

#define SOUND      "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga"
#define SOUND_SECS 180
#define NONE       0xffffffffu
#define UNSET      0xfffffffeu
#define PUTS(s)    put(s, sizeof(s) - 1)

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

/* 0-9 and ':' (index 10) */
static const char *f57[11][7] = {
	{ ".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###." },
	{ "..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###." },
	{ ".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####" },
	{ ".###.", "#...#", "....#", "..##.", "....#", "#...#", ".###." },
	{ "...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#." },
	{ "#####", "#....", "####.", "....#", "....#", "#...#", ".###." },
	{ "..##.", ".#...", "#....", "####.", "#...#", "#...#", ".###." },
	{ "#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..." },
	{ ".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###." },
	{ ".###.", "#...#", "#...#", ".####", "....#", "...#.", ".##.." },
	{ ".", ".", "#", ".", "#", ".", "." },
};
static const char *f35[11][7] = {
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
static const struct { const char *(*g)[7]; int h; } fonts[] = { { f57, 7 }, { f35, 5 } };

static volatile sig_atomic_t quit, resized;
static struct termios oldtio;
static sigset_t origmask;

static int cols, rows, pw, ph;
static double cx, cy, R, r;
static float *ain, *aout, *ang, *dist;
static uint32_t *grid;
static char *buf;
static size_t blen, bcap;

/* ring state for the current frame */
static enum { CLOCK, TIMER, ALARM } mode;
static double hlstart, frac;
static Col active, dimmed, flash;

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

static uint32_t
pack(Col c)
{
	return (uint32_t)lround(c.r) << 16 | (uint32_t)lround(c.g) << 8 | (uint32_t)lround(c.b);
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
	for (i = 0; i < CDATE; i++) {
		if (parsecol(conf[i].val, &c, &a) < 0)
			continue;
		col[i] = i == CBG ? c : lerp(col[CBG], c, a);
	}
}

static void
geometry(void)
{
	struct winsize ws;
	double thick, dx, dy, d, o, in;
	size_t n;
	int x, y;

	if (ioctl(STDOUT_FILENO, TIOCGWINSZ, &ws) < 0 || !ws.ws_col || !ws.ws_row)
		ws.ws_col = 80, ws.ws_row = 24;
	cols = ws.ws_col;
	rows = ws.ws_row;
	pw = cols;
	ph = rows * 2;
	cx = pw / 2.0;
	cy = ph / 2.0;
	R = ((pw < ph ? pw : ph) - 2) / 2.0;
	thick = fmax(2, round(R * 0.1));
	r = R - thick;

	n = (size_t)pw * ph;
	if (!(ain = realloc(ain, n * sizeof *ain)) || !(aout = realloc(aout, n * sizeof *aout)) ||
	    !(ang = realloc(ang, n * sizeof *ang)) || !(dist = realloc(dist, n * sizeof *dist)) ||
	    !(grid = realloc(grid, n * sizeof *grid)))
		exit(1);
	bcap = (size_t)cols * rows * 48 + (size_t)rows * 2 + 256;
	if (!(buf = realloc(buf, bcap)))
		exit(1);

	for (y = 0; y < ph; y++) {
		for (x = 0; x < pw; x++) {
			n = (size_t)y * pw + x;
			dx = x + 0.5 - cx;
			dy = y + 0.5 - cy;
			d = hypot(dx, dy);
			o = clamp(R - d + 0.5);
			in = clamp(r - d + 0.5);
			aout[n] = o;
			ain[n] = in;
			dist[n] = d;
			ang[n] = fmod(atan2(dx, -dy) / (2 * M_PI) + 1, 1);
		}
	}
}

/* half width of the inside circle at pixel row py */
static double
chord(int py)
{
	double dy = fabs(py + 0.5 - cy) + 0.5;

	return dy < r ? sqrt(r * r - dy * dy) - 1 : 0;
}

/* how much of a pixel at angle th lies on the arc [start, start + len] */
static double
arccover(double th, double d, double start, double len)
{
	double s, in;

	if (len >= 1)
		return 1;
	if (len <= 0)
		return 0;
	s = fmod(th - start + 2, 1);
	in = s <= len ? fmin(s, len - s) : -fmin(s - len, 1 - s);
	return clamp(in * 2 * M_PI * d + 0.5);
}

static Col
ringat(double th, double d)
{
	switch (mode) {
	case CLOCK: return lerp(col[CRING], col[CKEYHL], arccover(th, d, hlstart, 1.0 / 12));
	case TIMER: return lerp(dimmed, active, arccover(th, d, 0, frac));
	default:    return flash;
	}
}

static Col
gradient(double f)
{
	const double at[] = { 1.0, 0.6, 0.3, 0.0 };
	const Col c[] = { col[CRING], col[CVER], amber, col[CWRONG] };
	int i;

	for (i = 0; i < 3; i++)
		if (f >= at[i + 1])
			return lerp(c[i + 1], c[i], (f - at[i + 1]) / (at[i] - at[i + 1]));
	return c[3];
}

static int
glyph(char ch)
{
	return ch == ':' ? 10 : ch - '0';
}

static int
textwidth(const char *s, int fi, int scale)
{
	int w = 0, n = 0;

	for (; *s; s++, n++)
		w += strlen(fonts[fi].g[glyph(*s)][0]);
	return (w + n - 1) * scale;
}

static void
put(const char *s, size_t n)
{
	if (blen + n <= bcap) {
		memcpy(buf + blen, s, n);
		blen += n;
	}
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

/* place one text line on the cell row starting at pixel row py if it fits inside */
static void
textrow(int py, const char *str, int *trow, int *tcol, const char **tstr, int *tlen, int *nt)
{
	int len = strlen(str);

	if (!len || py < 0 || py / 2 >= rows || len / 2.0 > fmin(chord(py), chord(py + 1)))
		return;
	trow[*nt] = py / 2;
	tcol[*nt] = (int)lround(cx - len / 2.0);
	tstr[*nt] = str;
	tlen[*nt] = len;
	(*nt)++;
}

static void
render(const char *big, const char *small)
{
	int fi, best = -1, scale = 0, s, h, w, gap, y0, x, y, gx, gy, sx, sy, dy;
	int i, k, slen = strlen(small), cw = 0, nt = 0, trow[2], tcol[2], tlen[2];
	const char *tstr[2];
	uint32_t tc, ic, top, bot, fg = UNSET, bg = UNSET, f, b;
	double o, in;
	const char *p, *ch;
	size_t n;
	Col rc, c;

	if (r < 7) {
		PUTS("\33[0m\33[H\33[2J");
		for (i = 0; i < rows / 2; i++)
			PUTS("\r\n");
		for (i = 0; i < (cols - (int)strlen(big)) / 2; i++)
			PUTS(" ");
		put(big, strlen(big));
		PUTS("\r\n");
		for (i = 0; i < (cols - slen) / 2; i++)
			PUTS(" ");
		put(small, slen < cols ? slen : cols);
		flush();
		return;
	}

	for (n = 0; n < (size_t)pw * ph; n++) {
		o = aout[n];
		if (o <= 0) {
			grid[n] = NONE;
			continue;
		}
		in = ain[n];
		rc = o - in > 0 ? ringat(ang[n], dist[n]) : col[CBG];
		c.r = col[CINSIDE].r * in + rc.r * (o - in) + col[CBG].r * (1 - o);
		c.g = col[CINSIDE].g * in + rc.g * (o - in) + col[CBG].g * (1 - o);
		c.b = col[CINSIDE].b * in + rc.b * (o - in) + col[CBG].b * (1 - o);
		grid[n] = pack(c);
	}

	tc = pack(col[CTEXT]);
	ic = pack(col[CINSIDE]);
	for (fi = 0; fi < 2; fi++) {
		s = (int)fmin(r * 2 * 0.78 / textwidth(big, fi, 1), r * 2 * 0.40 / fonts[fi].h);
		if (s >= 1 && (best < 0 || s * fonts[fi].h > scale * fonts[best].h))
			best = fi, scale = s;
	}
	if (best >= 0) {
		h = fonts[best].h * scale;
		w = textwidth(big, best, scale);
		gap = scale * 2 > 2 ? scale * 2 : 2;
		y0 = (int)lround(cy - (h + gap + 2) / 2.0);
		x = (int)lround(cx - w / 2.0);
		for (p = big; *p; p++) {
			const char *const *g = fonts[best].g[glyph(*p)];
			cw = strlen(g[0]);
			for (gy = 0; gy < fonts[best].h; gy++)
				for (gx = 0; gx < cw; gx++)
					if (g[gy][gx] == '#')
						for (sy = 0; sy < scale; sy++)
							for (sx = 0; sx < scale; sx++) {
								int px = x + gx * scale + sx, py = y0 + gy * scale + sy;
								if (px >= 0 && px < pw && py >= 0 && py < ph)
									grid[(size_t)py * pw + px] = tc;
							}
			x += (cw + 1) * scale;
		}
		dy = y0 + h + gap;
		textrow(dy + (dy & 1), small, trow, tcol, tstr, tlen, &nt);
	} else {
		/* too small for big digits: plain text in the middle */
		textrow(rows / 2 * 2 - 2, big, trow, tcol, tstr, tlen, &nt);
		textrow(rows / 2 * 2, small, trow, tcol, tstr, tlen, &nt);
	}

	PUTS("\33[0m\33[H");
	for (y = 0; y < rows; y++) {
		if (y)
			PUTS("\r\n");
		for (x = 0; x < cols; x++) {
			for (k = 0; k < nt && !(y == trow[k] && x >= tcol[k] && x < tcol[k] + tlen[k]); k++);
			if (k < nt) {
				ch = &tstr[k][x - tcol[k]];
				n = 1;
				f = tc;
				b = ic;
			} else {
				top = grid[(size_t)(2 * y) * pw + x];
				bot = grid[(size_t)(2 * y + 1) * pw + x];
				n = 3;
				if (top == NONE && bot == NONE)
					ch = " ", n = 1, f = fg, b = NONE;
				else if (top == bot)
					ch = " ", n = 1, f = fg, b = top;
				else if (bot == NONE)
					ch = "\342\226\200", f = top, b = NONE;
				else if (top == NONE)
					ch = "\342\226\204", f = bot, b = NONE;
				else
					ch = "\342\226\200", f = top, b = bot;
			}
			if (f != fg)
				sgr(38, fg = f);
			if (b != bg)
				sgr(48, bg = b);
			put(ch, n);
		}
	}
	PUTS("\33[0m");
	flush();
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
	struct termios tio;
	struct sigaction sa = { 0 };
	struct pollfd pfd = { STDIN_FILENO, POLLIN, 0 };
	struct timespec ts;
	sigset_t block;
	double deadline = now(CLOCK_MONOTONIC) + total, paused = -1, rem, t, alarmat = 0, bell = 0, wait;
	pid_t player = 0, pid;
	int sound = access(SOUND, R_OK) == 0, status, i;
	ssize_t nr;
	time_t tt;
	struct tm tm;

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
	mode = total > 0 ? TIMER : CLOCK;

	while (!quit) {
		if (resized) {
			resized = 0;
			geometry();
			PUTS("\33[0m\33[2J");
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
			hlstart = tm.tm_sec / 60.0 - 1.0 / 24;
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
			frac = rem / total;
			active = gradient(frac);
			dimmed = lerp(col[CINSIDE], active, 0.3);
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
			flash = (long)(t * 2) % 2 ? lerp(col[CINSIDE], col[CWRONG], 0.3) : col[CWRONG];
			strcpy(big, "00:00");
			strcpy(small, "time's up, press any key");
			wait = 0.5 - fmod(t, 0.5) + 0.005;
		}

		render(big, small);

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
	PUTS("\33[0m\33[?25h\33[?1049l");
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
