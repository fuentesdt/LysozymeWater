set datafile commentschars "#@&"
set term png             
set output "potential.png"
plot "potential.xvg" using 1:2 with lines
