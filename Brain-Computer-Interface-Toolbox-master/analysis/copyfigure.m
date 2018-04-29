function copyfigure(oldFigHandle)
%copyfigure(oldFigHandle)
% Copy the contents of one figure into a new figure. Specify the handle of
% the figure to copy in 'oldFigHandle'. Without 'oldFigHandle' will create 
% a new figure and copy the contents of whichever figure is current.
%
% Example usage:
%  copyfigure(1)
%
% Y.Mishchenko (c) 2015

if(nargin<1 || isempty(oldFigHandle))
  %get handle of the old (current) figure
  oldFigHandle = gcf;
end

% create new figure 
newFigHandle = figure;

% copy the contents from one figure the other
copyobj(get(oldFigHandle , 'children'), newFigHandle);

end