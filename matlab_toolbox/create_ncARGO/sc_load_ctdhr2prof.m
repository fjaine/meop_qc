% load fr data

EXP=info_deployment.EXP;
PI=info_deployment.PI;
NATION=info_deployment.NATION;

list_tag = dir([info_deployment.dir,'*_lr0_prof.nc']);
for index=1:length(list_tag)
    
    smru_name = list_tag(index).name(1:end-12);
    [Lia,Locb]=ismember(smru_name,list_deployment_hr{:,1});
    if ~Lia, continue, end
    
    name_prof = sprintf('%s%s_lr0_prof.nc',info_deployment.dir,smru_name);
    num_file = list_deployment_hr{1,2}{Locb};
    if ~exist(name_prof,'file'), continue, end
    
    Mqc = ARGO_load_qc(name_prof,1);
    data_att = ncloadatt_struct(name_prof);
    listatt = fieldnames(data_att);
    file = [conf.rawdir_hr num2str(list_deployment_hr{1,3}(Locb)) '/'  num_file '_ctd.txt'];
    fid = fopen(file);
    tline = fgetl(fid);
    fclose(fid);
    
    %% chargement du fichier ctd haute resolution
    clear F O;
    isfluo=0; isoxy=0;
    Fluo = strfind(tline,'Fluo');
    Oxy =strfind(tline,'Oxy');
    
    %% cas des balises qui n'enregistrent que la remontee de certaies profils
    if list_deployment_hr{1,5}(Locb)==0
        
        if length(Fluo)==0 & length(Oxy)==0
            [date,P,T,S] = ...
                textread(file,'%s%f%f%*f%f',...
                'delimiter','\t','headerlines',1);
            F=T.*NaN;
            O=T.*NaN;
            
        elseif length(Fluo)>0 & length(Oxy)==0
            [date,P,T,S,F] = ...
                textread(file,'%s%f%f%*f%f%f',...
                'delimiter','\t','headerlines',1);
            isfluo=double(length(find(F~=999))~=0);
            O=T.*NaN;
            
        elseif length(Fluo)==0 & length(Oxy)>0
            [date,P,T,S,O] = ...
                textread(file,'%s%f%f%*f%f%f',...
                'delimiter','\t','headerlines',1);
            isoxy=double(length(find(O~=999))~=0);
            F=T.*NaN;
            
        end
        
        % on cherche le debut de chaque profil en cherchant les sauts temporelles
        date=datenum(date,'yyyy/mm/dd HH:MM:SS');
        dif_temp=date(4)-date(1);
        Ihead=find(diff(date)>dif_temp);
        Ihead=[Ihead;length(date)];
        N=length(Ihead);
        % on associe chaque profil HR avec une localisation des profils BR et on
        % interpole pour le reste.
        
        lat=Ihead*NaN;
        lon=Ihead*NaN;
        
        for ii=1: length(Mqc.JULD)
            [m,I]=min(abs(Mqc.JULD(ii)-date(Ihead)));
            lat(I)=Mqc.LATITUDE(ii);
            lon(I)=Mqc.LONGITUDE(ii);
            
        end
        lat=interp1(date(Ihead(~isnan(lat))),lat(~isnan(lat)),date(Ihead));
        lon=interp1(date(Ihead(~isnan(lon))),lon(~isnan(lon)),date(Ihead));
        
        % creation des profils de remontes pour la haute resolution
        grilleHdpres=NaN*zeros(6000,N);
        grilleHdtemp=NaN*zeros(6000,N);
        grilleHdsal=NaN*zeros(6000,N);
        grilleHdfluo=NaN*zeros(6000,N);
        grilleHdoxy=NaN*zeros(6000,N);
        
        plongee=[];
        plongee=[P(1:Ihead(1)),T(1:Ihead(1)),S(1:Ihead(1)),F(1:Ihead(1)),O(1:Ihead(1))];
        [m,J]=max(plongee(:,1));
        plongee(1:J-1,:)=[];
        [profil,ia,ic]=unique(plongee(:,1));
        grilleHdtemp(1:length(profil),1)=plongee(ia,2);
        grilleHdpres(1:length(profil),1)=profil;
        grilleHdsal(1:length(profil),1)=plongee(ia,3);
        grilleHdfluo(1:length(profil),1)=plongee(ia,4);
        grilleHdoxy(1:length(profil),1)=plongee(ia,5);
        
        for ii=2:N
            plongee=[];
            plongee=[P(Ihead(ii-1)+1:Ihead(ii)),T(Ihead(ii-1)+1:Ihead(ii)),S(Ihead(ii-1)+1:Ihead(ii))...
                ,F(Ihead(ii-1)+1:Ihead(ii)),O(Ihead(ii-1)+1:Ihead(ii))];
            [m,J]=max(plongee(:,1));
            plongee(1:J-1,:)=[];
            [profil,ia,ic]=unique(plongee(:,1));
            grilleHdtemp(1:length(profil),ii)=plongee(ia,2);
            grilleHdpres(1:length(profil),ii)=profil;
            grilleHdsal(1:length(profil),ii)=plongee(ia,3);
            grilleHdfluo(1:length(profil),ii)=plongee(ia,4);
            grilleHdoxy(1:length(profil),ii)=plongee(ia,5);
        end
        
    else % cas des balises qui enregistrent en continue durant tout le trajet
        
        [date,P,T,S] = ...
            textread(file,'%s%f%f%*f%f%*f',...
            'delimiter','\t','headerlines',1);
        F = T.*NaN;
        O = T.*NaN;
        date = datenum(date,'yyyy/mm/dd HH:MM:SS');
        
        % soucis dans les fichiers tres haute resolution la salinite a des
        % valeurs completements fausses a� la remontee ( svt egale a 0 ou negative)
        S(S<3)=NaN;
        tdr=[date,P,T,S];
        
        % fonction de detection des plongees (identique a celle utilisee pour les tdr)
        [statdives,info_ana_dives,statdivestxt,datadives,datadivestxt,chg,daindexes] = ...
            ana_dives_fabien(tdr);
        N = length(statdives);
        lat = chg(2,:)'*NaN;
        lon = chg(2,:)'*NaN;
        ind = chg(2,:)'*NaN;
        for ii=1:length(Mqc.JULD)
            [m,ik] = min(abs(Mqc.JULD(ii)-date(chg(2,:))));
            lat(ik) = Mqc.LATITUDE(ii);
            lon(ik) = Mqc.LONGITUDE(ii);
            ind(ik) = chg(2,ik);
        end
        I = find(~isnan(lat) & ~isnan(lon));
        lat = interp1(date(ind(I)),lat(I),date(chg(2,:)),'linear','extrap');
        lon = interp1(date(ind(I)),lon(I),date(chg(2,:)),'linear','extrap');
        n0 = length(find(date(chg(2,:))-Mqc.JULD(1)<1))+length(find(date(chg(2,:))-Mqc.JULD(end)>1));
        if n0, 
            disp([smru_name ': warning! location of ' num2str(n0) ' fr_profiles were extrapolated']);
        end
        Ihead=chg(2,:)';
        
        % creation des profils de remontees
        grilleHdpres=NaN*zeros(6000,length(statdives));
        grilleHdtemp=NaN*zeros(6000,length(statdives));
        grilleHdsal=NaN*zeros(6000,length(statdives));
        grilleHdfluo=NaN*zeros(6000,length(statdives));
        grilleHdoxy=NaN*zeros(6000,length(statdives));
        for ii=1:length(statdives)-1
            plongee=[];
            plongee=tdr(daindexes(2,ii):chg(2,ii),:);
            [m,J]=max(plongee(:,2));
            plongee(1:J-1,:)=[];
            [profil,ia,ic]=unique(plongee(:,2));
            grilleHdtemp(1:length(profil),ii)=plongee(ia,3);
            grilleHdpres(1:length(profil),ii)=profil;
            grilleHdsal(1:length(profil),ii)=plongee(ia,4);
        end
        plongee=[];
        plongee=tdr(daindexes(2,end):chg(2,end),:);
        [m,J]=max(plongee(:,2));
        plongee(1:J-1,:)=[];
        [profil,ia,ic]=unique(plongee(:,2));
        grilleHdtemp(1:length(profil),N)=plongee(ia,3);
        grilleHdpres(1:length(profil),N)=profil;
        grilleHdsal(1:length(profil),N)=plongee(ia,4);
        
    end
    
    %% Save traj files
    sc_write_traj_file;
    
    %% interpolation sur une grille r�guliere des donn�es brutes
    prof=[1:1000];
    prof_temp_interp=NaN*zeros(length(prof),length(N));
    prof_pres_interp=NaN*zeros(length(prof),length(N));
    prof_sal_interp=NaN*zeros(length(prof),length(N));
    prof_fluo_interp=NaN*zeros(length(prof),length(N));
    prof_oxy_interp=NaN*zeros(length(prof),length(N));
    
    
    for ll=1:N
        I=find(~isnan(grilleHdpres(:,ll)));
        if length(I)>2
            [pressinter,ia,ic]=unique(grilleHdpres(I,ll));
            tempinter=[];
            salinter=[];
            fluointer=[];
            oxyinter=[];
            for kk=1:length(pressinter)
                tempinter(kk,1)=grilleHdtemp(ia(kk),ll);
                salinter(kk,1)=grilleHdsal(ia(kk),ll);
                fluointer(kk,1)=grilleHdfluo(ia(kk),ll);
                oxyinter(kk,1)=grilleHdoxy(ia(kk),ll);
            end
            prof_temp_interp(:,ll)=interp1(pressinter,tempinter,prof);
            prof_sal_interp(:,ll)=interp1(pressinter,salinter,prof);
            prof_fluo_interp(:,ll)=interp1(pressinter,fluointer,prof);
            prof_oxy_interp(:,ll)=interp1(pressinter,oxyinter,prof);
        elseif length(I)==1
            [m,J]=min(abs(grilleHdpres(I(1),ll)-prof));
            prof_temp_interp(:,ll)=NaN;
            prof_temp_interp(J,ll)=grilleHdtemp(I(1),ll);
            prof_sal_interp(:,ll)=NaN;
            prof_sal_interp(J,ll)=grilleHdsal(I(1),ll);
            prof_fluo_interp(:,ll)=NaN;
            prof_fluo_interp(J,ll)=grilleHdfluo(I(1),ll);
            prof_oxy_interp(:,ll)=NaN;
            prof_oxy_interp(J,ll)=grilleHdoxy(I(1),ll);
            
        end
        prof_pres_interp(:,ll)=prof;
    end
    
    %% write fcell files
    hi=zeros(N,10);
    hs={};
    for kk=1:N,
        hs(kk)={smru_name};
    end
    hi(:,2)=index;
    hi(:,3)=1:N;
    hi(:,4)=date(Ihead);
    hi(:,5:6)=[lat lon];
    hi(:,9)=1;
    hi(:,10)=hi(:,2);
    
    PTi=cell(1,N); PSi=cell(1,N);
    PFi=cell(1,N); POi=cell(1,N);
    
    P=prof_pres_interp;
    T=prof_temp_interp;
    S=prof_sal_interp;
    F=prof_fluo_interp;
    O=prof_oxy_interp;
    T(T==999)=NaN; S(S==999)=NaN;
    F(F==999)=NaN; O(O==999)=NaN;
    
    Ihead2=[Ihead;length(P)+1];
    nprof=1; ntag=1; pold=0;
    for ii=1:N,
        
        PTi{ii}=[P(:,ii) T(:,ii)];
        PSi{ii}=[P(:,ii) S(:,ii)];
        PFi{ii}=[P(:,ii) F(:,ii)];
        POi{ii}=[P(:,ii) O(:,ii)];
        hi(ii,8)=sum(~isnan(T(:,3)));
        
    end
    
    % find bad location
    I=find(hi(:,5)~=0);
    hi=hi(I,:);
    PTi=PTi(I); PSi=PSi(I);
    PFi=PFi(I); POi=POi(I);
    hs=hs(I);
    
    % correct dates: put them back to Matlab julian date norm
    hi(hi(:,4)<1e5,4)=hi(hi(:,4)<1e5,4)+693962;
    
    % sort date
    I=zeros(1,length(PTi));
    ltag=unique(hi(:,10));n=0;
    for kk=1:length(ltag),
        J=find(hi(:,10)==ltag(kk));
        [a,K]=sort(hi(J,4));
        I(n+1:n+length(J))=J(K);
        n=n+length(J);
    end
    hi=hi(I,:);
    PTi=PTi(I); PSi=PSi(I);
    PFi=PFi(I); POi=POi(I);
    hs=hs(I);
    
    %save fcell
    name_fcell=[conf.temporary_fcell info_deployment.EXP '_fr0_fcell.mat'];
    save(name_fcell,'hi','hs','PTi','PSi','PFi','POi','EXP','PI','NATION','isoxy','isfluo');
    
    %% save in Argo netcdf format
    if length(hi)>0
        suffix = 'fr0_prof.nc';
        convert_fcell2ARGO(conf,info_deployment.EXP,name_fcell,suffix,1000);
    end
    
    
end