classdef gen_lc < handle
    properties(Access = protected)
        
        
        
    end
    properties(Access = private)
    end
    properties(GetAccess = public,SetAccess=private)
    end
    properties(GetAccess = public,SetAccess=protected)
    end
    properties(Access = public)
        c
        datafiles
        predt
        postdt
        chidx
        ftid
        target
        
    end
    methods(Access=private)
    end
    methods(Access=protected)
    end
    
    methods(Access=public)
        function learning_curve_calculator(this)
            
            fprintf('Learning curves calculation for EEG BCI...\n');
            if(nargin<6) this.ftid=[]; end
            if (nargin<7 || isempty(this.target)) this.target=1; end
        end
        function prepare_data_samples(this)
            fprintf('Preparing samples...\n');
            [ft,ftmrk]=ftprep(this.datafiles,this.predt,this.postdt,this.chidx);
            this.target=sort(this.target);
            ttidx=find(ismember(ftmrk,this.target));
            nn=length(ttidx);     %number of epochs
            global xvalsequential 	%sequential/random train-validation split modifier
            if isempty(xvalsequential) ,xvalsequential=false; end
            testthr=0.10; %train-validation -- test split
            if (xvalsequential)     %test subset
                fprintf('Sequential x-validation split\n');
                act_flgtest=(1-(1:nn)/nn)<testthr;
            else
                fprintf('Random x-validation split\n');
                act_flgtest=rand(1,nn)<testthr;
            end
        end
        function scan_loop(this)
            [ft,ftmrk]=ftprep(this.datafiles,this.predt,this.postdt,this.chidx);
            ttidx=find(ismember(ftmrk,this.target));
            nn=length(ttidx);
            Ntrains=50:50:floor(nn*3/4);
            Mtests=5;   %passes to evaluate errorbars
            prc=zeros(3,Mtests,length(Ntrains));
            pcnt=0;
            ecnt=0;
            for Ntrain=Ntrains
                pcnt=pcnt+1;
                
                m=1;
                while m<=Mtests
                    %% constrain trials
                    idx=1:nn;
                    idx=idx(randperm(length(idx)));
                    idx=idx(1:min(length(idx),Ntrain));
                    ft.tridx=ttidx(idx);
                    
                    %% train classifier
                    try
                        [obj ,pp]=this.c(this.datafiles,this.predt,this.postdt,this.chidx,this.ftid,this.target,ft,ftmrk,act_flgtest(idx));
                    catch E
                        if ecnt<3
                            ecnt=ecnt+1;
                            continue;
                        else
                            pp(:)=NaN(3,1);
                        end
                    end
                    
                    prc(:,m,pcnt)=pp(:);
                    ecnt=0;
                    m=m+1;
                end
            end
        end
        function graph_learning_curves(this)
            figure,errorbar(repmat(Ntrains',1,3),squeeze(mean(prc,2))',squeeze(std(prc,[],2))')
            legend('Train','Validation','Test','Location','SouthEast')
            grid on
        end
        
    end
end
