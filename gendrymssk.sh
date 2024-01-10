#!/bin/sh
for i in $(seq 1 8); do
	fname="textures/nc_paint_drymask_$i.png"
	./drymasker.lua $i 42 \
		| convert -size 16x16 -depth 8 RGBA:- PNG32:"$fname"
	echo $fname
	catimg "$fname"
done
