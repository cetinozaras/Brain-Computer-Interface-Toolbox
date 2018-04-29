function nkanalysis_erp(fname,trials,chs,reref,dirname)
%nkanalysis_erp(datafiles,trials,chs,dirname)
% Batch file for the analysis of trials-ERP from a data run contained in
% 'datafiles'. 'datafiles' is a cell array of file names pointing to the 
% eeg data to be processed. The eeg data in all data-files should be 
% uniformly stored in variable 'o', in emotiv output-file format.'trials'
% is the array of marker ids identifying marker values to be analyzed.
% chs is the array of EEG channel ids to be analyzed. 'reref' is the array
% of the EEG channel ids whose average is to be used as the new system 0V,
% that is, the new reference. 'dirname' is the name of the directory to
% where the figures of ERP will be saved.
%
% Example usage:
%  nkanalysis_erp({'pilot20150625-nk.mat'},[1 2],1:21,[11 12],'p2015xxx')
%
%Y.Mishchenko (c) 2015

if(nargin<4) reref=[]; end

%parameters
ploterp=true;         %plot erp
plotpdf=true;         %plot pdf
subtrials=[];         %restrict erp to average only over some trials


%% Load data
%examples
% fname={'pilot20150625-nk.mat'};
% fname={'nkdeney-yuriy-20150916-ofull.mat'};


%get trials out of the time series
load(fname{1});
tr=trials_make(o,0.5,1);

%restrict subtrials
if(~isempty(subtrials))
    for  i=trials tr{i}=tr{i}(subtrials,:,:); end
end

%% Plots
if(ploterp)
    %plot trials
    fmts={'b-','r--','g-.','m--','c-.','k--','b:','r:','g:','m:','c:','k:'};
    
    for i=trials
      trials_erp(tr{i},1,o.sampFreq,true,fmts{i},chs,reref);
    end
end

if(nargin>=4 && ~isempty(dirname))
  savefigs(chs,[dirname,'\erps']);
  close all
end

if(plotpdf)
    %plot pdfs
    for i=trials
      trials_pdf(tr{i},chs,1.5);
      
      if(nargin>=4 && ~isempty(dirname))
        savefigs(1:length(chs),[dirname,sprintf('\\pdfs%i_',i)]);
        close all
      end      
    end
end

end
