function trials_pdf(trial,chs,dt,nn)
%trials_pdf(trial,chs,dt,nn)
% Display ERP pdf in a trial.
% Usage example:
% trials_pdf(tr{1});

if(nargin<4 || isempty(nn)) nn=256; end
if(nargin<3 || isempty(dt)) dt=1; end
if(nargin<2 || isempty(chs)) chs=1:size(trial,3); end

data=trials_norm(trial);

for k=chs
  tr=data(:,:,k);
  
  %tr=tr-repmat(mean(tr,2),[1 size(tr,2)]);
  
  xmean=mean(tr(:));
  xstd=std(tr(:));
  
  %x-range for the data
  xmin=xmean-3*xstd;
  xmax=xmean+3*xstd;
  dx=(xmax-xmin)/(nn-1);
  
  %get [eeg-amplitude,time] of each data point
  Aidx=min(nn,max(1,round((tr-xmin)/dx)+1));
  Tidx=repmat(1:size(tr,2),[size(tr,1) 1]);
  
  %convert [eeg-amplitude,time] into indexes on time x amplitude image
  ATidx=sub2ind([size(tr,2) max(Aidx(:))],Tidx(:),Aidx(:));
      
  %count # of hits for each time x amplitude pixel
%   ss=regionprops(ATidx,'Area');  
%   idx=find([ss.Area]);
%   vals=[ss(idx).Area];
  [idx,vals]=ssort(ATidx);
  
  %fill # of hits into a 'pdf' image
  pdf=zeros(size(tr,2),max(Aidx(:)));
  pdf(idx)=vals;
  
  %plot this
  tt=(1:size(tr,2))/size(tr,2)*dt*1000;
  xx=xmin:dx:xmax;
  figure,imagesc(tt,xx,pdf')
  axis xy
  xlabel('miliseconds')
  ylabel('microvolts')
  title(sprintf('channel %i',k))
end


  function [idx vals]=ssort(data)
    sdata=sort(data(:));
    idata=[1;diff(sdata);1];
    idx=find(idata);
    vals=diff(idx);
    idx=sdata(idx(1:end-1));    
  end

end


