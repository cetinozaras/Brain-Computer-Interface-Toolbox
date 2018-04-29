function [ftidx,ranks,nid]=parse_ftid(ftid,ft,xeegsamples,xmrktargets,target)
%[ftidx,ranks,nid]=parse_ftid(ftid,ft,xeegsamples,xmrktargets,target)
%Utility function performing parsing the feature pre-selection identifier
%'ftid' and performing necessary feature ranking and selection based on
%'ftid' for training-learning functions in this section.
%
% Feature pre-selector can be specified in one of following ways: 
% - if 'ftid' is empty, default slow-ERP selector is implied (handled by 
 %   make-features) and nothing is done;
% - if 'ftid' is an array of size 1 x n_feature, direct feature selection 
%    is implied (handled by make_features) and nothing is done; In these 
%    cases parse_ftid returns 'rankids' and 'nids' corresponding to the
%    full received featureset;
% - if 'ftid' is a string of the form "[fs][MET][cs][NUM]";
%    [fs] is a single character identifying type of features to be used, 
%    (also used by make_features) and can be one of the following
%    'tXXX' to use time-series features,
%    'sXXX' to use FT amplitude features (re/im), 
%    'aXXX' to use FT amplitude features (abs/angle), 
%    'pXXX' to use PSD features in quadratic form, 
%    'dXXX' to use PSD features in log (dB) form,
%    'eXXX' to use EEG band power features.
%    [MET] is a alphabetic specifier identifying the feature ranking to be 
%    used for ranking of features, can be one of the following
%    'xMUIxxx' to use Mutual Information-based ranking of features,
%    'xFRQxxx' to use low-pass frequency selector,
%    'xFRQxxx-xxx' to use band-pass frequency selector,
%    'xKLDxxx' to use Kullback-Leibler divergence ranking of features
%     (not supported for #targets>2)
%    'xCORxxx' to use correlation-based ranking of features 
%    [cs] is a single character specifying the type of method to use for
%    selecting the features by their rank, can be 
%    'XXXzNUM' to select top features based on a z-score-type threshold, in
%     which case features with rank-scores NUM times STD above rank-score
%     average are selected;
%    'XXXnNUM' to select a fixed number of features starting from highest
%     rank-scores in descending order;
%    [NUM] is the numerical threshold (if [cs]=='z') or the number of
%    features (if [cs]=='n') to be selected.
%
% Y.Mishchenko (c) 2017


%enable default selector
if isempty(ftid)
  ftid='sFRQz5.01';
end

%adjust ftid if char
if ischar(ftid)
  feature_type=ftid(1);

  if length(ftid)>2
    selector_type=ftid(2:4);
  else
    selector_type='';
  end
  
  if length(ftid)>4    
    cutoff_type=ftid(5);
  else
    cutoff_type='';
  end
  
  if length(ftid)>5 
    cutoff_value=ftid(6:end);
  else
    cutoff_value='';
  end
end


%rank features if requested
if ~ischar(ftid)
  fprintf('''ftid'' is not alphanumeric...\n');
  ranks=[];
  ftidx=1:sum(ftid);
  nid=length(ftidx);
  return
else  
  fprintf('Ordering features ''%s''...\n',ftid);
    
  if strcmpi(selector_type,'MUI') 
    %mui based selector, can be multi-target
    ranks=xftr_mui(xeegsamples,xmrktargets,target);
    [ranks,ranksid]=sort(ranks,'descend');
    m=mean(ranks); s=std(ranks); 
    num1=str2double(cutoff_value); num2=Inf;    
  elseif strcmpi(selector_type,'KLD') 
    %KLD based selector, do not use for multi-target
    ranks=xftr_kld(xeegsamples,xmrktargets);
    [ranks,ranksid]=sort(ranks,'descend');
    m=mean(ranks); s=std(ranks);
    num1=str2double(cutoff_value); num2=Inf;    
  elseif strcmpi(selector_type,'COR') 
    %COR based selector
    ranks=xftr_r2(xeegsamples,xmrktargets);
    [ranks,ranksid]=sort(ranks,'descend');
    m=nanmean(ranks); s=nanstd(ranks);
    num1=str2double(cutoff_value); num2=Inf;    
  elseif strcmpi(selector_type,'FRQ') 
    %FRQ based selector
    if feature_type=='e' || feature_type=='h'
      ranks=ft.eegfreqid;
    elseif feature_type=='p' || feature_type=='d'
      ranks=ft.freqid;
    elseif feature_type=='s' || feature_type=='a'
      ranks=[ft.freqid,ft.freqid];
    elseif feature_type=='t'
      ranks=zeros(size(xeegsamples,2),1);
    else
      error('parse_ftid: Cannot use FRQ with this feature-type');
    end
    
    m=0; s=1;
    
    dash_position=strfind(cutoff_value,'-');
    if ~isempty(dash_position)
      %if cutoff is in the form 'minNUM-maxNUM', parse directly
      num1=str2double(cutoff_value(1:dash_position-1));
      num2=str2double(cutoff_value(dash_position+1:end));
    else
      %if cutoff is in the form 'NUM', assume '0-NUM'
      num1=0;
      num2=str2double(cutoff_value);
    end
    
    [ranks,ranksid]=sort(ranks,'ascend');
  else  %no valid selector chosen, pass all
    fprintf('Empty or invalid selector, returning all\n');
    ftidx=1:size(xeegsamples,2);
    nid=length(ftidx);
    ranks=zeros(size(ftidx));
    return
  end
  
  if feature_type=='t' && strcmpi(selector_type,'FRQ') 
    ftidx=1:size(xeegsamples,2);
    nid=length(ftidx);
  elseif strcmpi(cutoff_type,'z')
    %Z-type cutoff
    ftidx=ranksid((ranks-m)>=num1*s & (ranks-m)<=num2*s);
    nid=length(ftidx);
  elseif strcmpi(cutoff_type,'n')
    %number of features-type cutoff
    nid=min(length(ranks),str2double(cutoff_value));
    ftidx=ranksid(1:nid);
  else
    %no cutoff specified (will be selected downstream)
    ftidx=ranksid;
    nid=0;
  end
  
  fprintf('Pre-selected features %i\n',nid);
end

end
