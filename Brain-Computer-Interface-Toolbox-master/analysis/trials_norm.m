%Normalize trials to zero mean and select data channels.
function [data channels]=trials_norm(trials)
%[tdata tchannels]=trials_norm(trials)
% Normalize trials to zero mean and select data channels. "trials" is
% a 3D matrix with dimensions n_trials x n_time x n_channels.
%
%Y. Mishchenko (c) 2014

% select valid trials
idx=max(max(abs(trials),[],2),[],3);
data=trials(idx>0,:,:);

% subtract mean from all trials
data=data-repmat(mean(data,2),[1 size(data,2) 1]);

% select data channels
channels=zeros(1,size(trials,3));
for k=1:size(trials,3)
  channels(k)=std(reshape(data(:,:,k),1,[]));
end
channels=find(channels>max(channels)/3);