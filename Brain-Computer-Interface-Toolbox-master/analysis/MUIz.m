function mui=MUIz(X,Z)
%mui=MUIz(X,Z)
%Mutual information estimation for a continuous + discrete variables.
% X should be p1 x n array of n observations of the realizations of a 
% p1-dimensional continuous-valued random variable X, Z should be a 
% p2 x n array of the observations of a p2-dimensional discrete-valued 
% random variable Y. The number of the observations of both X and Z 
% MUST be the same, n.
%
% If X is empty or absent, returns a hard-wired test result.
%
% If X is nonempty and Z is empty or absent, returns the entropy 
% of X, H(X); this can be used to compute MUI for two continuous 
% variables as HXY=MUIz(X)+MUIz(Y)-MUIz([X;Y]).
%
% Y.Mishchenko (c) 2015

%This implements MUI(X,Z)=H(X)-H(X|Z) where H(X|Z)=sum_z n(z)/N*H(X|Z==z).
%For continuous entropy estimator H(X|*) see MUI.m

k=5;        %kth nearest neighbor choice

if(nargin<1 || isempty(X))
  p=10;      %dimensionality of points
  n=10E2;    %sample size
  s1=1.0;    %scale factor
  X=s1*randn(p,n);
  Z=rand(1,n)>sum(X,1);
elseif(nargin<2 || isempty(Z))
  mui=H(X);
  return
end

%this computes H(X)
HX=H(X);

%this computes H(X|Z)
HXZ=0;
nn=size(Z,2);
[Zv,Zn]=EFRQ(Z);
for k=1:size(Zv,2)
  idx=max(Z==repmat(Zv(:,k),[1 nn]),[],1);
  hxz=H(X(:,idx));
  HXZ=HXZ+hxz*Zn(k)/nn;
end
fprintf('EHX %g\nEHXZ %g\n',HX,HXZ);

%MUI=H(X)-H(X|Z)
mui=HX-HXZ;

  function [val,frq]=EFRQ(Z)
    %build empirical frequencies n (and values in v)    
    p=size(Z,1);
    n=size(Z,2);
    
    val=sortrows(Z')';
    idx=find([max(diff(val,1,2),[],1)~=0,1]);
    val=val(:,idx);
    frq=diff([0,idx]);
  end

  function EH=H(X)
    %calculate entropy estimate for a continuous r.v. X
    p=size(X,1);
    n=size(X,2);    
    
    %matrix of all-to-all distances
    D=dist(X);
    
    %sort along 2nd dimension (rows)
    D=sort(D,2);
    
    %pick out kth-nearest neighbor distances
    RK=D(:,k+1);
    
    %form E[H] using SMHFD estimator
    EH=p/n*sum(log(RK))+log(pi^(p/2)/(k*gamma(p/2+1)))-psi(k)+log(k)+log(n);
  end

end