function [ccobj, pp]=gen_tr(funcTrain,funcClassify,datafiles,predt,postdt,chid,ftid,targets,ft,ftmrk,testid)
%[rfobject pp]=gen_tr(funcTrain,funcClassify,dataFiles,predt,postdt,chid,ftid,targets,ft,ftmrk,testid)
% Train a general category classifier for multiclass EEG BCI
% classification. funcTrain and funcClassify are function handlers for own
% training and classification functions. These should have the signatures:
% function classifierObject=funcTrain(trainExamples,trainTargets,...
%  validationExamples,validationTargets)
% function labels=ownclassify(classifierObject,examples)
%
% This is a scaffold file intended to be used with other specialized
% training functions. See the help of such other functions for the meaning
% of the other parameters.
%
% Y.Mishchenko (c) 2016

%Undocumented feature, `global xvalsequential` is used to specify whether
%training/validation split should be randomized (false) or sequntial (true)

%% Parameters
xvalThr=0.70;     %train-validation split
testThr=0.1;      %{train-validation}-test split
nnmax=10000;      %max number of examples to use in training

global xvalsequential 	%sequential/random train-validation split modifier
global commonmode       %subtraction mode modifier

if isempty(xvalsequential) xvalsequential=false; end

if nargin<5 ftid=[]; end
if nargin<6 || isempty(targets) targets=[1 2]; end


%% Prepare features
fprintf('Preparing features...\n');

%use precomputed features if ft and ftmrk were provided, otherwise
%compute the features yourself
if nargin<8 || isempty(ft) || isempty(ftmrk)
    [ft,ftmrk]=ftprep(datafiles,predt,postdt,chid,commonmode,ftid);
end

%make features
[trialExamples,trialLabels]=make_features(ft,ftmrk,ftid);


%% Prepare trials
%if trial-idx field of ft was passed, constrain the samples to include
%only the specific trials selected in ft.tridx
if isfield(ft,'tridx')
    trialExamples=trialExamples(ft.tridx,:);
    trialLabels=trialLabels(ft.tridx);
end

%constrain examples to contain only the desired 'targets'
targets=sort(targets);
idx=ismember(trialLabels,targets);
trialExamples=trialExamples(idx,:);
trialLabels=trialLabels(idx);

fprintf('#########################\n');
fprintf('Total examples %i\n',size(trialExamples,1));
fprintf('Total features %i\n',size(trialExamples,2));
fprintf('#########################\n');


%% Prepare train-validation-test datasets
%normalize features to zero mean/unit variance
%(do it here so that affects all datasets below, no need to recompute)
msamples=mean(trialExamples,1);
ssamples=std(trialExamples,[],1)+1E-12;
trialExamples=bsxfun(@minus,trialExamples,msamples);
trialExamples=bsxfun(@rdivide,trialExamples,ssamples);

%define {training-validation}/test split (always randomized)
nn=size(trialExamples,1);        %number of examples
if nargin<9 || isempty(testid)
    testid=rand(1,nn)<testThr;
end

%define training/validation split (controlled by global xvalsequential)
if xvalsequential
    fprintf('Sequential x-validation split\n');
    trainid=((1:nn)/nn)<xvalThr;
else
    fprintf('Random x-validation split\n');
    trainid=rand(1,nn)<xvalThr;
end

%training dataset, randomize order
idx=find(trainid & ~testid);
idx=idx(randperm(length(idx)));
idx=idx(1:min(length(idx),nnmax));
trainExamples=trialExamples(idx,:);
%break degeneracies (hurtful for some methods)
trainExamples=trainExamples+1E-6*randn(size(trainExamples));
trainTargets=trialLabels(idx);


%validation dataset
idx=find(~trainid & ~testid);
idx=idx(randperm(length(idx)));
valExamples=trialExamples(idx,:);
valTargets=trialLabels(idx);

%test dataset
idx=find(testid);
idx=idx(randperm(length(idx)));
testExamples=trialExamples(idx,:);
testTargets=trialLabels(idx);



%% Prepare classifier object
%perform feature ranking and selection
[ftidx,ranks,nid]=parse_ftid(ftid,ft,trialExamples,trialLabels,targets);

if nid>0
    %restrict feature sets to such selected in ftidx for
    %train and validation data
    ctexamples=trainExamples(:,ftidx);
    cttargets=trainTargets;
    cvexamples=valExamples(:,ftidx);
    cvtargets=valTargets;
    
    %train classifier, looping over any internal hyperparameters
    clobj=funcTrain(ctexamples,cttargets,cvexamples,cvtargets);
else
    %automatically select the number of features to keep
    dnn=25;           %initial num of features and the increment step
    dnn_stop=4;       %number of increments without improvement before stop
    dnn_stop2=10;     %number of increments without improvement before stop
    dnn_cnt=0;        %counter of increments without improvement
    dnn_cnt2=0;       %counter of increments without improvement
    dnn_mininc=2E-2;  %minimal required improvement
    dnn_mininc2=1E-3; %minimal required improvement
    
    xclobj=[];          %best classifier
    xnid=[];          %best nid
    xp=-[Inf,Inf];%previous performance values
    for nid=dnn:dnn:length(ranks)
        ftidx_=ftidx(1:nid);
        
        %restrict feature sets to such selected in ftidx_
        ctexamples=trainExamples(:,ftidx_);
        cttargets=trainTargets;
        cvexamples=valExamples(:,ftidx_);
        cvtargets=valTargets;
        
        %train classifier, looping over any internal hyperparameters
        clobj=funcTrain(ctexamples,cttargets,cvexamples,cvtargets);
        
        %check performance on validation set
        xtest=funcClassify(clobj,cvexamples);
        p2=mean(cvtargets==xtest);
        
        %check performance on test set
        ctexamples=testExamples(:,ftidx_);
        cttargets=testTargets;
        
        xtest=funcClassify(clobj,ctexamples);
        p3=mean(cttargets==xtest);
        
        %evaluate stopping condition -
        % no improvement for dnn_stop increments
        if (xp(1)>p2+dnn_mininc || xp(2)>p3+dnn_mininc)
            dnn_cnt=dnn_cnt+1;
        else
            xclobj=clobj;
            xnid=nid;
            xp=[p2,p3];
            dnn_cnt=0;
        end
        
        if (p2<xp(1)+dnn_mininc2 && p3<xp(2)+dnn_mininc2)
            dnn_cnt2=dnn_cnt2+1;
        else
            dnn_cnt2=0;
        end
        
        fprintf(' best number of features search %i: (%g,%g)...\n',nid,p2,p3);
        
        if dnn_cnt>dnn_stop || dnn_cnt2>dnn_stop2
            break;
        end
    end
    
    ftidx=ftidx(1:xnid);
    clobj=xclobj;
    
    fprintf(' ===selected %i: (%g,%g)...\n',xnid,xp);
end


%check final performance on training set
xtest=funcClassify(clobj,trainExamples(:,ftidx));
p1=nanmean(trainTargets==xtest);
fprintf('Training %g\n',p1);

%check final performance on validation set
xtest=funcClassify(clobj,valExamples(:,ftidx));
p2=nanmean(valTargets==xtest);
fprintf('X-validation %g\n',p2);


%check final performance on test set
xtest=funcClassify(clobj,testExamples(:,ftidx));
p3=nanmean(testTargets==xtest);
fprintf('Test %g\n',p3);

%% output
% train-validation-test performances
pp=[p1 p2 p3];

%category classifier object
ccobj=[];
ccobj.ftidx=ftidx;                    %used features
ccobj.meantrf=msamples(ftidx);        %subtracted means
ccobj.stdtrf=ssamples(ftidx);         %divided STD
ccobj.categoryClassifier=clobj;        %classifier object

end
