function [ftdata,mrkdata,ftidx]=make_features(ft,ftmrk,ftid,verb)
%[ftdata mrkdata ftidx]=make_features(ft,ftmrk[,ftid,verb])
% Companion function for ftprep, convert the output of ftprep to
% n_trials x n_feature matrix of features ('ftdata') and corresponding
% n_trials x 1 vector of labels ('mrkdata').
%
% 'ftid' specifies which type of features is to be produced from ftprep.
% 'ftid' can be given as a string such as
% - "all" - returns all features from ftprep,
% - 'xXXX' - returns all features from ftprep (with subsequent
%            feature pre-selection such as MUI,KLD or COR [no FRQ!])
% - 'tXXX' - returns time-series features,
% - 'sXXX' - returns FT amplitude features as re/im,
% - 'aXXX' - returns FT amplitude features as abs/angle,
% - 'pXXX' - returns PSD features as amplitude-square,
% - 'dXXX' - returns PSD features as log10 (dB),
% - 'eXXX' - returns EEG band power features as amplitude square,
% - 'hXXX' - returns EEG band power features as log10 (dB),
%
% Skip or specify 'ftid' as [] for default selector, which is
% the slow (freq<=5Hz) FT amplitudes in re/im form.
%
% Specify 'ftid' as logical 1 x n_feature vector to directly select the
% features from the array of all ftprep-features. The order of the features
% in the array of all ftprep-features is [ft.tseries,ft.eegpow,
% ft.(db)eegpow,ft.pow,ft.(db)pow,ft.real,ft.imag,ft.ampl,ft.angle].
%
% 'verb' specifies the level of verbocity.
%
% Upon completion returns the corresponding features, labels, and the
% logical 1 x n_features feature selector-vector in 'ftdata','mrkdata' and
% 'ftidx', respectively.
%
% Example usage:
%  [ftdata, mrkdata, ftidx]=ftget(ft,ftmrk,[])
%
%Y. Mishchenko (c) 2016

if nargin<4 || isempty(verb)
    verb=0; end

if isempty(ftid)
    ftid='sFRQz5.01';
end

nults=false(size(ft.tsampleid));
onets=true(size(ft.tsampleid));
nulft=false(size(ft.freqid));
oneft=true(size(ft.freqid));
nulpsd=false(size(ft.freqid));
onepsd=true(size(ft.freqid));
nuleeg=false(size(ft.eegfreqid));
oneeeg=true(size(ft.eegfreqid));

if verb>0
    fprintf('ftprep-feature vector''s structure:\n{\n');
    fprintf(' - Time-series features %i\n',length(nults));
    fprintf(' - EEG band-power features %i\n',length(nuleeg));
    fprintf(' - EEG band-power (dB) features %i\n',length(nuleeg));
    fprintf(' - PSD features %i\n',length(nulpsd));
    fprintf(' - PSD (dB) features %i\n',length(nulpsd));
    fprintf(' - FT amplitude-real features %i\n',length(nulft));
    fprintf(' - FT amplitude-imaginary features %i\n',length(nulft));
    fprintf(' - FT amplitude-abs features %i\n',length(nulft));
    fprintf(' - FT amplitude-angle features %i\n}\n',length(nulft));
end

e=1E-6;
if nargin<3 || isempty(ftid)
    %default selector, FT re/im + freqid<=5 (Hz)
    ftdata=[real(ft.ft(:,ft.freqid<=5)),imag(ft.ft(:,ft.freqid<=5))];
    ftidx=[nults,nuleeg,nuleeg,nulpsd,nulpsd,ft.freqid<=5,ft.freqid<=5,nulft,nulft];
elseif ischar(ftid)
    if(strcmpi(ftid,'all') || ftid(1)=='x')
        ftdata=cat(2,ft.tseries,ft.eegpow,log10(ft.eegpow+e),...
            ft.pow,log10(ft.pow+e),real(ft.ft),imag(ft.ft),abs(ft.ft),angle(ft.ft));
        ftidx=true(1,size(ftdata,2));
    elseif(ftid(1)=='t')
        ftdata=ft.tseries;
        ftidx=[onets,nuleeg,nuleeg,nulpsd,nulpsd,nulft,nulft,nulft,nulft];
    elseif(ftid(1)=='s')
        ftdata=[real(ft.ft),imag(ft.ft)];
        ftidx=[nults,nuleeg,nuleeg,nulpsd,nulpsd,oneft,oneft,nulft,nulft];
    elseif(ftid(1)=='a')
        ftdata=[abs(ft.ft),angle(ft.ft)];
        ftidx=[nults,nuleeg,nuleeg,nulpsd,nulpsd,nulft,nulft,oneft,oneft];
    elseif(ftid(1)=='e')
        ftdata=ft.eegpow;
        ftidx=[nults,oneeeg,nuleeg,nulpsd,nulpsd,nulft,nulft,nulft,nulft];
    elseif(ftid(1)=='h')
        ftdata=log10(ft.eegpow+e);
        ftidx=[nults,nuleeg,oneeeg,nulpsd,nulpsd,nulft,nulft,nulft,nulft];
    elseif(ftid(1)=='p')
        ftdata=ft.pow;
        ftidx=[nults,nuleeg,nuleeg,onepsd,nulpsd,nulft,nulft,nulft,nulft];
    elseif(ftid(1)=='d')
        ftdata=log10(ft.pow+e);
        ftidx=[nults,nuleeg,nuleeg,nulpsd,onepsd,nulft,nulft,nulft,nulft];
    else
        fprintf(' Warning (make_features): unrecognized ftid string;\n');
        fprintf(' defaulting to freqid<=5Hz\n');
        ftdata=[real(ft.ft(:,ft.freqid<=5)),imag(ft.ft(:,ft.freqid<=5))];
        ftidx=[nults,nuleeg,nuleeg,nulpsd,nulpsd,ft.freqid<=5,ft.freqid<=5,nulft,nulft];
    end
else
    ftdata=cat(2,ft.tseries,ft.eegpow,log10(ft.eegpow+e),...
        ft.pow,log10(ft.pow+e),real(ft.ft),imag(ft.ft),abs(ft.ft),angle(ft.ft));
    ftdata=ftdata(:,ftid);
    ftidx=ftid;
end

fprintf('Total %i values\n',sum(ftidx));

%prepare labels array
if nargin>1 && nargout>1
    mrkdata=ftmrk;
end

end
