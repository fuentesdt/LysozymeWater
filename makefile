# http://www.bevanlab.biochem.vt.edu/Pages/Personal/justin/gmx-tutorials/lysozyme/index.html
GMX=gmx
VMD=/opt/apps/VMD/vmd-1.9.3-install/vmd-1.9.3-install/vmd_LINUXAMD64
view:
	vglrun $(VMD) 1AKI.pdb
	echo  (also load trajectory file: md_0_1.trr) extensions -> vis -> movie maker
	vglrun $(VMD) md_0_1.gro 


#15: OPLS-AA/L all-atom force field (2001 aminoacid dihedrals)
posre.itp topol.top 1AKI_processed.gro: 1AKI.pdb 
	echo 1  | $(GMX) pdb2gmx -f 1AKI.pdb  -o 1AKI_processed.gro -water spce 

1AKI_newbox.gro: 1AKI_processed.gro
	$(GMX) editconf -f 1AKI_processed.gro -o 1AKI_newbox.gro -c -d 1.0 -bt cubic

1AKI_aceticacid.gro: 1AKI_newbox.gro
	$(GMX) insert-molecules  -ci C2H4O2.pdb -nmol 1000  -f  $< -o 1AKI_aceticacid.gro
	echo '_I0M         1000' >>  topol.top
	sed -i '8660i  #include "C2H4O2.itp"'  topol.top

1AKI_solvaceticacid.gro: 1AKI_aceticacid.gro
	$(GMX) solvate -cp $< -cs spc216.gro -o $@ -p topol.top

1AKI_solv.gro: 1AKI_newbox.gro
	$(GMX) solvate -cp $< -cs spc216.gro -o $@ -p topol.top

ions.tpr: 1AKI_solv.gro
	$(GMX) grompp -f ions.mdp -c 1AKI_solv.gro -p topol.top -o ions.tpr

#	echo 13 | $(GMX) genion -s ions.tpr -o 1AKI_solv_ions.gro -p topol.top -pname NA -nname CL -nn 8 
#	Group    13 (            SOL) has 36846 elements
# add enough NaCl to reach 100 mM salt concentration
# http://ringo.ams.sunysb.edu/index.php/MD_Simulation:_Protein_in_Water
1AKI_solv_ions.gro: ions.tpr
	echo 13 | $(GMX) genion -s ions.tpr -p topol.top -o 1AKI_solv_ions.gro -pname NA -pq 1 -nname CL -nq -1 -conc 0.4 -neutral

#em.gro: 1AKI_solvaceticacid.gro
em.gro: 1AKI_solv_ions.gro
	$(GMX) grompp -f minim.mdp -c $< -p topol.top -o em.tpr
	$(GMX) mdrun -v -deffnm em -nb gpu

potential.png: em.edr
	echo 10 0 | $(GMX) energy -f em.edr -o potential.xvg 
	#At the prompt, type "10 0" to select Potential (10); zero (0) terminates input.
	gnuplot potential.plt  

nvt.tpr: em.gro
	$(GMX) grompp -f nvt.mdp -c em.gro -p topol.top -o nvt.tpr

nvt.edr: nvt.tpr
	$(GMX) mdrun -v -deffnm nvt -nb gpu

energy.png: nvt.edr
	echo 15 0 | $(GMX) energy -f nvt.edr -o energy.xvg 
	#Type "15 0" at the prompt to select the temperature of the system and exit.
	gnuplot energy.plt  
npt.tpr:
	$(GMX) grompp -f npt.mdp -c nvt.gro -t nvt.cpt -p topol.top -o npt.tpr
npt.ttr:
	$(GMX) mdrun -v -deffnm npt -nb gpu
pressure.xvg: npt.edr
	echo 16 0 | $(GMX) energy -f npt.edr -o pressure.xvg 
	#Type "16 0" at the prompt to select the pressure of the system and exit. 
density.xvg:
	echo 22 0 | $(GMX) energy -f npt.edr -o density.xvg
md_0_1.tpr:
	$(GMX) grompp -f md.mdp -c npt.gro -t npt.cpt -p topol.top -o md_0_1.tpr
md_0_1.xtc:
	$(GMX) mdrun -deffnm md_0_1 -nb gpu
md_0_1_noPBC.xtc:
	echo 0 | $(GMX) trjconv -s md_0_1.tpr -f md_0_1.xtc -o md_0_1_noPBC.xtc -pbc mol -ur compact 
	#Select 0 ("System") for output.
rmsd.xvg:
	echo 4 | $(GMX) rms -s md_0_1.tpr -f md_0_1_noPBC.xtc -o rmsd.xvg -tu ns 
	#Choose 4 ("Backbone") for both the least squares fit and the group for RMSD calculation.
rmsd_xtal.xvg:
	$(GMX) rms -s em.tpr -f md_0_1_noPBC.xtc -o rmsd_xtal.xvg -tu ns
gyrate.xvg:
	$(GMX) gyrate -s md_0_1.tpr -f md_0_1_noPBC.xtc -o gyrate.xvg
