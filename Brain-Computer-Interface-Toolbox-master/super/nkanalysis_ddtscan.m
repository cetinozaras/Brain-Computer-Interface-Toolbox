%Batch file for analysis of NK experiment results.
%Edit the file to run over your set of data.
%
%Y.Mishchenko (c) 2015

%% definitionsnkdeney-hilmi-fivefingerext-20151229
%define experiment's prefix
prefix='nkdeney-Batuhan-FiveFingerHF-20160804';

alldata=sprintf('%s.mat',prefix);
dirname=sprintf('analysis-%s',prefix);

%define nk-marker channel
nkmarker=22;

%define if will create spectrograms
fspectr=false;

%define useful trials and EEG channels
tridx=[5,4,3,2,1];      %ids of useful trials marker values
predt=0.00;          %epoch pre-length (prior-to-stimulus), sec
postdt=0.85;         %epoch post-length (post-to-stimulus), sec
chidx=1:21;         %data channels



predts=-1.0:0.1:1.0;
framedts=0.1:0.1:2.0;
Z=zeros(length(predts),length(framedts));
ZS=Z;
for i=1:length(predts)
    for j=1:length(framedts)
        predt=-predts(i);
        postdt=framedts(j)-predt;
        
        if predt>=0 & postdt<=0
            fprintf('(%g sec)|<-- %g sec -->|(%g sec)--*\n',-predt,framedts(j),postdt);
        elseif predt>0 & postdt>0
            fprintf('(%g sec)|<-- %g sec -- * -->|(%g sec)\n',-predt,framedts(j),postdt);
        else
            fprintf('*--(%g)|<-- %g sec -->|(%g sec)\n',-predt,framedts(j),postdt);
        end
            
        
        [svmo pp]=mcsvm_tr({alldata},predt,postdt,chidx,[],sort(tridx));
        
        Z(i,j)=(pp(2)+pp(3))/2;     %mean test performance
        ZS(i,j)=abs(pp(2)-pp(3));   %variation in test performance
    end
end

figure,mesh(framedts,predts,Z)
xlabel('Frame length (predt+postdt), sec')
ylabel('-predt, sec')
title('dt-ddt SCAN')
saveas(gcf,[dirname,'/dtddtscan.fig'])
save([dirname,'/dtddtscan.mat'],'predts','framedts','Z','ZS')
