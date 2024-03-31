#!/bin/dash

geometry="$(slurp)"
sleep "0.15"
grim -g "${geometry}" - | swappy -f -
