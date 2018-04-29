function [trials markers]=trials_make2(eegdata,marker,dt1,dt2)
%[trials markers]=trials_make2(eegdata,marker,dt1,dt2)
% Produce trials for EEG data described by EEG data 'eegdata' and marker
% data 'marker'. This function operates on EEG data represented in the 
% form of {time x channels} matrix (may be merged from different 
% experiments) and may be more suitable for use in toolchains.
%
% 'eegdata' is n_samples x n_channels matrix of EEG readings , 'marker' is 
% n_samples x 1 array of trial stimulus values aligned with EEG samples 
% in 'eegdata', dt1' and 'dt2' are before-stimulus and after-stimulus 
% onset epoch lengths (IN SAMPLES!).
%
% Returned 'trials' is {n_trials x n_samples x n_channels} matrix of EEG 
% data fragment for each trial and 'markers' is {n_trials x 1} matrix of
% trial stimulus value of each trial.
%
% Example usage:
%  [trials,markers]=trials_make2(eegdata,marker,100,200,3E4);
%
%Y.Mishchenko (c) 2016


%% Initialize
nch=size(eegdata,2);  %number of channels
dt=ceil(dt1+dt2);     %epoch length, samples
ddt=ceil(dt2);        %epoch length after stimulus on-edge, samples


%% Find epochs


%construct epoch on/off markers
idx=find(diff(marker)>0);     %stimulus on-edge
idxon=idx(1:end-1)+ddt;
idx=find(diff(marker)<0);     %stimulus off-edge
idxoff=idx(1:end-1)+ddt;
xidx=union(idxon,idxoff);     %merge on/off

markers=marker(xidx-ddt+1); %epochs' marker values

idx=1:length(xidx);
idx=idx(markers(idx)>0);

%% Prepare samples
nn=length(idx);
trials=zeros(nn,dt,nch);
for k=1:nn
  tp=xidx(idx(k));        %kth epoch end point
  trials(k,:,:)=eegdata(tp-dt+1:tp,:);
end

markers=markers(idx);

end