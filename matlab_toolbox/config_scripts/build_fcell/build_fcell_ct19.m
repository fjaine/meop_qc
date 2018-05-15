%% ct19

%% remove tags

%% apply corrections
list_tag = dir([info_deployment.dir,'*_prof.nc']);
sc_init_corrections;

calib_coeff.ct19 = [
	1	0.00	0.00	0.00	0.00
	2	0.00	0.00	0.00	0.6
	3	0.00	0.00	0.00	0.00
    ];

temp_error=0.1;
psal_error=0.2;

minT=-2.5; maxT=20; minS=25; maxS=40; min_Nprof=30;
