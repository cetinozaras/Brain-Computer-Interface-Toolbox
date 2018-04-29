function o=ftr_out1ch(datafiles,predt,postdt,chidx,target,train_fnc)
%mui=ftr_out1ch(datafiles,predt,postdt,chs,target)
% Calculate channel ordering based on take-one-out ranking for BCI target. 
% 'datafiles' is a cell array of file names pointing to the eeg data to
% be processed. The eeg data in all data-files should be uniformly stored 
% in variable 'o', in emotiv output-file format. 'predt' and 'postdt' are 
% before and after stimulus-onset epoch lengths, in seconds. 'chs' is 
% the array of indexes of the useful eeg-data channels in the data.
% 'target' is the classifier target, 1-vs-all training model. Produces 
% array 'o' in which the firt row is the list of channels in the
% most-significant->list-significant order, second row is the associated
% validation accuracies and third row is the associated external test
% accuracies. 'train_fnc' is reference to training function (such as
% @svm_tr or @mcsvm_tr). 
%
% Example usage:
%  o=ftr_out1ch({'nkdeney-example.mat'},0.0,0.85,1:21,1);
%  o=ftr_out1ch({'nkdeney-example.mat'},0,0.85,1:21,[1 2 3 4 5],@mcsvm_tr);
%
%Y.Mishchenko (c) 2015


%% Load data (merge all listed experiments)

%Examples
% datafiles={};

%old pilot, real motion left/right wrist
% datafiles={'pilot20141225.mat','pilot20141229.mat'};

%new pilot-1, imaged motion left/right wrist
% datafiles={datafiles{:},'pilot20150618-1.mat','pilot20150618-2.mat'};
% datafiles={datafiles{:},'pilot20150618-3.mat','pilot20150618-4.mat'};

%new pilot-2, real/img motion right wrist/left hand
% datafiles={datafiles{:},'pilot20150623-1.mat','pilot20150623-2.mat'};
% datafiles={datafiles{:},'pilot20150623-3.mat','pilot20150623-4.mat'};
% datafiles={datafiles{:},'pilot20150623-5.mat'};

%nk-pilot-1
% datafiles={datafiles{:},'pilot20150625-nk.mat'};

%nk-pilot-2
% datafiles={datafiles{:},'nkdeney-yuriy-20150916.mat'};

%nk-pilot-3
% datafiles={datafiles{:},'nkdeney-yuriy-20150917.mat'};

% predt=0.25;  %epoch pre-length (prior stimulus), sec
% postdt=0.85; %epoch post-length (post stimulus), sec
% chidx=1:21;   %data channels


% dt=ceil(0.65*frq);      %classified epoch length
% ddt=ceil(0.85*frq);     %classified epoch end relative to stimulus onset
% ofs=2.5*60*frq;           %excluded part of recording, 2.5min

nch=length(chidx);  %number of channels
testthr=0.1;        %train-validation -- test split
freqthr=5;          %frequency threshold, Hz

if(nargin<6)
    train_fnc=@svm_tr;
end

%% PREPARE FEATURES
fprintf('Preparing features...\n');

%no-recompute flag
[ft ftmrk]=ftprep(datafiles,predt,postdt,chidx);

%% PRELIMINARIES
%eeg,bpow and pow/powdb null-selectors in ft
nulft=false(size(ft.freqid));
nuleeg=false(size(ft.freqeeg));

%setup other prelims
channelsin=[];
channelsout=chidx;
tres=zeros(1,nch);
ttres=zeros(1,nch);
act_flgtest=rand(1,size(ft.real,1))<testthr;

%% MAIN LOOP
cnt=1;
fprintf('All channels...\n');
ftidx=ft.freqid<=freqthr;
ftidx=cat(2,ftidx,ftidx);

% form full ftidx selector for svm_tr
xftidx=[nuleeg,nulft,nulft,ftidx];

% run svm_tr and get results
[o,pp]=train_fnc(datafiles,predt,postdt,chidx,xftidx,target,ft,ftmrk,act_flgtest);
p1=pp(1); p2=pp(2); p3=pp(3);

% store results
tres(cnt)=min(p1,p2);
ttres(cnt)=p3;

cnt=2;
while(length(channelsout)>1)
    res=zeros(1,nch);
    rest=zeros(1,nch);
    for i=channelsout
        % add one of the remaining channels in and update ftidx feature
        % selector to include that channel in addition to channelsin
        fprintf('Remove channel %i...\n',i);
        tmpchannels=setdiff(channelsout,i);
        ftidx=ft.freqid<=freqthr & ismember(ft.chid,tmpchannels);
        ftidx=cat(2,ftidx,ftidx);
        
        % form full ftidx selector for svm_tr
        xftidx=[nuleeg,nulft,nulft,ftidx];

        % run svm_tr and get results
        [o,pp]=train_fnc(datafiles,predt,postdt,chidx,xftidx,target,ft,ftmrk,act_flgtest);        
        p1=pp(1); p2=pp(2); p3=pp(3);
        
        % store results
        res(i)=min(p1,p2);
        rest(i)=p3;
    end
    
    % select highest gain channel and take record
    [r i]=max(res);
    tres(cnt)=r;
    ttres(cnt)=rest(i);
    cnt=cnt+1;
    
    % add channel to channelsin, preserving order, 
    % and remove from channelsout
    channelsin=cat(2,channelsin,i);
    channelsout=setdiff(channelsout,i);
end

%invert order
channelsin=cat(2,channelsin,channelsout);
channelsin=channelsin(end:-1:1);
tres=tres(end:-1:1);
ttres=ttres(end:-1:1);

o=[channelsin;tres;ttres];

end
