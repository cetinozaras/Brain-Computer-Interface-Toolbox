function [Z,ZS,Z1,predts,postdts]=ddtscan(c,datafiles,chidx,ftid,target,verb,ints)
%[Z,ZS,Z1,predts,framedts]=ddtscan(c,datafiles,chidx,ftid,target,verb,pr_ints)
% Perform a scan of the initial and final offsets of detection window
% for a given BCI-trials classifier and select best performance.
% 'c' is the function reference to the classifier training function, such 
% as svm_tr or mnlr_tr, taking inputs (datafiles,predt,postdt,chidx,ftid,
% target,ft,ftmrk,act_flgtest). 'datafiles' is a cell array of o-data 
% files containing the EEG data. 'chidx' is the array of  indexes of the 
% eeg-data channels to pass to @c. 'ftid' is the features selector to pass
% to @c. 'target' is the set of BCI targets to pass to @c. 'verb' is the 
% level of verbocity in the output. 'ints', if specified, instructs ddtscan 
% to go through a list of dt-ddt intervals as specified in ints, instead of 
% a full dtxddt grid search.
%
% Returns matrix Z and ZS of size length(predts)xlength(framedts)
% containing the average and the STD of the classifier's validation 
% performance on predts(i):framedts(j) detection window. Z1 contains the
% average classifier's test performance on the same windows (for control).
%
% Example usage:
%  [Z,ZS]=ddtscan(@mcsvm_tr,{'nkdeney-example.mat'},1:21,'sFRQz5',[1 2 3]);
%
% Y.Mishchenko (c) 2016

%bias smaller ddt in results by about dz=0.1 per 100 msec max dz=0.5

if nargin<6
  verb=2;
end
if nargin<7
  ints=[];
end

%% initial configs
predts=0.0:0.1:0.5;            %starting offsets, sec
postdts=[0.2:0.1:1.0,1.2,1.5];  %ending offsets, sec
repM=4;                 %performance averaging, passes
testfrc=0.1;            %percentage of test cases

if isempty(ints)        %form intervals & matrix shapes
  [A,B]=meshgrid(predts,postdts);
  ints=[A(:),B(:)];
else
  predts=unique(ints(:,1));
  postdts=unique(ints(:,2));
end

Z=zeros(length(predts),length(postdts));
ZS=Z;
Z1=Z;

%set train/validation split in @c to randomized
global xvalsequential   
xvalsequential=false;
global commonmode

%define the test control cases, needs to be done once and for all
[ft,ftmrk]=ftprep(datafiles,0,1,chidx,commonmode,ftid);
ttidx=ismember(ftmrk,target);
nn=sum(ttidx);
act_flgtest=rand(1,nn)<testfrc;

accu=cell(1,length(ints));
parfor idx=1:length(ints)
  predt=-ints(idx,1);
  postdt=ints(idx,2);
  
  i=find(-predt==predts);
  j=find(postdt==postdts);
  
%   predt=-predts(i);
%   postdt=postdts(j);
  
  %do not look at improperly formed frames
  if postdt<(-predt+0.1)
    continue;
  end
  
  if verb>0
    if predt>=0 && postdt<=0
      fprintf('(%g sec)|<-- %g sec -->|(%g sec)--*\n',-predt,predt+postdt,postdt);
    elseif predt>0 && postdt>0
      fprintf('(%g sec)|<-- %g sec -- * -->|(%g sec)\n',-predt,predt+postdt,postdt);
    else
      fprintf('*--(%g)|<-- %g sec -->|(%g sec)\n',-predt,predt+postdt,postdt);
    end
  end
  
  %calculate features only once for a selection of predt and postdt
  [ft,ftmrk]=ftprep(datafiles,predt,postdt,chidx,commonmode,ftid);
  ttidx=ismember(ftmrk,target);
  
  %check that had data, eg frame is smaller than sampling frequency
  if isnan(ft.ft(1))
    continue;
  end
  
  pp1=zeros(repM,3);
  for k=1:repM
    [svmo,pp]=c(datafiles,predt,postdt,chidx,ftid,target,ft,ftmrk,act_flgtest);
    pp1(k,:)=pp;
  end
  
  accu{idx}={mean(pp1(:,2)),...       %mean validation performance
    std(pp1(:,2)),...       %variation in validation performance
    mean(pp1(:,3))};       %mean test performance  

end
  
% collect all
for idx=1:length(ints)
  if isempty(accu{idx})
    continue
  end
  
  predt=-ints(idx,1);
  postdt=ints(idx,2);
  
  i=find(-predt==predts);
  j=find(postdt==postdts);  
  
  Z(i,j)=accu{idx}{1};        %mean validation performance
  ZS(i,j)=accu{idx}{2};       %variation in validation performance
  Z1(i,j)=accu{idx}{3};       %mean test performance
end

if verb>1
  figure,imagesc(postdts,predts,Z)
  xlabel('Frame length (predt+postdt), sec')
  ylabel('-predt, sec')
  title('dt-ddt SCAN')
end

end
