#!/bin/sh

DMENU=~/Dev/local/dmenu
export PATH=$DMENU:$PATH

exec dmenu_run -fn "xft:Bitstream Vera Sans Mono:pixelsize=13:scalable=true:antialias=true" -p '>' -i -nb "#002b36" -nf "#839496" -sf "#cb4b16" -sb "#073642"
