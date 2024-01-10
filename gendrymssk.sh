#!/bin/sh
for i in 1 2 3 4; do
	fname="textures/nc_paint_drymask_$i.png"
	./drymasker.lua $i 42 \
		| convert -size 16x16 -depth 8 RGBA:- PNG32:"$fname"
	echo $fname
	catimg "$fname"
done
