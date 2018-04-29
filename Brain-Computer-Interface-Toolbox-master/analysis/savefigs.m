function savefigs(figids,prefix,fmt)
%savefigs(figids,prefix,fmt)
% Save a set of figures to a file in a loop. Specify the set of figure
% handles to loop over in 'figids'. Specify the prefix for the files to
% save the figures into in 'prefix' and the file extension of the files 
% formagt in 'fmt'.
%
% Example usage:
%  savefigs(1:31,'nkexperiment20150101','jpg')
%
% Y.Mishchenko (c) 2015

if(nargin<2 || isempty(prefix)) prefix='savefig'; end
if(nargin<3 || isempty(fmt)) fmt='jpg'; end


%loop over figids and save using saveas
for fig=figids
   fname=sprintf('%s%i.%s',prefix,fig,fmt);
   fprintf('Saving Figure %i -> %s\n',fig,fname);
   saveas(fig,fname);
end


end