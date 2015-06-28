set datafile commentschars "#@&"
set term png             
set output "energy.png"
plot "energy.xvg" using 1:2 with lines
