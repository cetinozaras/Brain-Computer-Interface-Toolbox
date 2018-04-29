function [erp_mean erp_std]=trials_erp(trial,style,sampFrq,overlay,fmt,chs,reref)
%[erp_mean erp_std]=trials_erp(trial,style,sampFreq,overlay,fmt,chs,reref)
% Calculate and display the average ERP for a trial matrix. 
% Example usage:
%  trials_erp(tr{1},1,200,true,'b-');
%  trials_erp(tr{2},1,200,true,'r--');
%
% trial     a 3D matrix of dimensions n_samples x n_time x n_channels.
% style     specify the type of graphical output to produce;
%    style==1, average ERP and SEM errorbars, one figure per EEG channel;
%    style==2, all average ERP on single plot figure;
%    style==3, all average ERPs on single matrix figure.
% sampFrq   specify sampFrq to label x-axis in ms (default 200 sample/sec).
% overlay   specify overlay=true to output all graphs on the same set of 
%    figures starting with figure(1) and so on, in "hold on" mode.
% fmt       specify fmt string to be used in plot commands for all figures.
% chs       specify subset of EEG channels to plot.
% reref     re-reference all data to specified channel, if given as an  
%    integer, or the average of specified channels, if given as array.
%
%Y.Mishchenko (c) 2014

if(nargin<2 || isempty(style)) style=3; end
if(nargin<3 || isempty(sampFrq)) sampFrq=200; end
if(nargin<4 || isempty(overlay)) overlay=false; end
if(nargin<5 || isempty(fmt)) fmt='.-b'; end
if(nargin<6 || isempty(chs)) chs=1:size(trial,3); end
if(nargin<7 || isempty(chs)) reref=[]; end

data=trials_norm(trial);
nsamples=size(data,1);

%rereference the data, if requestedd
if(~isempty(reref))
    nchannels=size(data,3);    
    newref=data(:,:,reref);
    newref=mean(newref,3);
    data=data-repmat(newref,[1 1 nchannels]);
end

erp_mean=squeeze(mean(data,1));
erp_std=squeeze(std(data,[],1))/sqrt(nsamples);
%remove nan's, can affect averages
erp_std(isnan(erp_std) | erp_std==0)=1E-5;

tt=size(erp_mean,1);
erp_ts=(1:tt)*1000/sampFrq;
if(style==1)
  for k=chs
    if(overlay)
      figure(k),hold on
    else 
      figure
    end
    errorbar(erp_ts,erp_mean(:,k),erp_std(:,k),fmt)
    grid on
    axis([0 max(erp_ts) min(erp_mean(:,k)-erp_std(:,k)) ...
      max(erp_mean(:,k)+erp_std(:,k))])
    ylim auto
    title(sprintf('Channel %i',k))
  end
elseif(style==2)
  figure,plot(erp_ts,erp_mean(:,chs)'),legend('toggle')
elseif(style==3)
  figure,imagesc(erp_mean(:,chs)')
  xlabel('samples'),ylabel('channels')
  colorbar
end

end