#!/usr/bin/env bash
# crop_png <in.png> <out.png> <L> <T> <W> <H>
crop_png() {
  ffmpeg -y -loglevel error -i "$1" -vf "crop=$5:$6:$3:$4,scale='min(480,iw)':-1" "$2"
}
# encode_gif <in.mov> <out.gif> <L> <T> <W> <H> <fps>
encode_gif() {
  local in="$1" out="$2" L="$3" T="$4" W="$5" H="$6" fps="${7:-18}"
  local pal="/tmp/cap_pal.png"
  ffmpeg -y -loglevel error -i "$in" -vf "crop=$W:$H:$L:$T,fps=$fps,scale='min(480,iw)':-1:flags=lanczos,palettegen=stats_mode=diff" "$pal"
  ffmpeg -y -loglevel error -i "$in" -i "$pal" -lavfi "crop=$W:$H:$L:$T,fps=$fps,scale='min(480,iw)':-1:flags=lanczos[x];[x][1:v]paletteuse=dither=bayer:bayer_scale=3" "$out"
}
