function [mui,HXY,HX,HY]=MUI2(X,Y,M)
%mui=MUI2(X,Y,M)
%Mutual information estimator for two 1D continuous variables.
% X should be 1 x n array of n observations of the realizations of a 
% 1D continuously-valued random variable X, Y should be a 1 x n array 
% of the observations of a 1D continuously-valued random variable Y. 
% The number of the observations of both X and Y MUST be the same, n.
% M is the number of bins to use in histograms.
%
% If X is empty or absent, returns a hard-wired test result.
%
% Y.Mishchenko (c) 2015

%For continuous variables mui(X,X)=Inf (H(X,X)->inf)

if(nargin<1 || isempty(X))
  p=1;      %dimensionality of points
  n=1E3;    %sample size
  M=33;
  s1=1;     %scale factor
  s2=0.1;
  X=s1*randn(p,n);
  Y=X+s2*randn(p,n);
end

%individual histograms and entropies
[hx1,nx1]=hist(X,M); hx1(hx1==0)=1; px1=hx1/sum(hx1);
w1=nx1(2)-nx1(1);        %bin width
HX=-sum(log(px1).*px1)+log(w1);

[hx2,nx2]=hist(Y,M); hx2(hx2==0)=1; px2=hx2/sum(hx2);
w2=nx2(2)-nx2(1);        %bin width
HY=-sum(log(px2).*px2)+log(w2);


%construct joint histogram out of the same bins

%This has a difficulty for closely correlated variables,
%since in that case the support of the XY-distribution 
%degenerates from rectangle into a line.

%Here we attempt to max-decorrelate X & Y by calculating 
%H(X,Y) not on the original variables but after substitution
%X->X, Y->Y-aX-b, which has jacobian 1

[hx1, ix1] = histc(X, [-inf nx1(1:end-1) + diff(nx1)/2, inf]);

[b bint r]=regress(Y',[X',ones(size(X'))]); r=r';
[hx2,nx2]=hist(r,M);
[hx2, ix2] = histc(r, [-inf nx2(1:end-1) + diff(nx2)/2, inf]);
w2=nx2(2)-nx2(1);

dd=[max(ix1),max(ix2)];
idx12=sub2ind(dd,ix1,ix2);

[nx12 hx12]=EFRQ(idx12);
hx12(hx12==0)=1; 
px12=hx12/sum(hx12);
HXY=-sum(log(px12).*px12)+log(w1*w2);

fprintf('EHX %g\nEHY %g\nEHXY %g\n',HX,HY,HXY);

mui=HX+HY-HXY;
fprintf('MUI %g\n',mui);

%diagnostics
fprintf('diag joint corr %g\n',corr(X',r'));


  function [val,frq]=EFRQ(Z)
    %build empirical frequencies n (and values in v)    
    p=size(Z,1);
    n=size(Z,2);
    
    val=sortrows(Z')';
    idx=find([max(diff(val,1,2),[],1)~=0,1]);
    val=val(:,idx);
    frq=diff([0,idx]);
  end

end