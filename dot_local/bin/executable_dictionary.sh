#!/bin/sh

word="$(wl-paste --primary)"

"${BROWSER}" "https://www.oxfordlearnersdictionaries.com/search/english/?q=${word}"
