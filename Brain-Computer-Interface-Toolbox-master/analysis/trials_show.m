%Display normalized trial tables. 
function data=trials_show(trial,style,chs)
%trials_show(trial,style,chs)
% Display trial tables. "trial" is a 3D matrix with dimensions 
% n_samples x n_time x n_channels. "Style" can be 1 or 3.
%
%Y.Mishchenko (c) 2015

if(nargin<2 || isempty(style)) style=3; end
if(nargin<3 || isempty(chs)) chs=1:size(trial,3); end

%normalize trial
data=trials_norm(trial);

%draw trials
if(style==1)
  for k=chs
    figure,plot(squeeze(data(:,:,k))')
    title(sprintf('Channel %i',k))
  end
elseif(style==3)
  for k=chs
    thisdata=squeeze(data(:,:,k));
    var=std(thisdata(:));
    thisdata=max(-3*var,min(3*var,thisdata));
    figure,imagesc(thisdata)
    title(sprintf('Channel %i',k))
  end
end

end