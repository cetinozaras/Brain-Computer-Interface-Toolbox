classdef mcbtr_tr <handle
    
    
    properties(Access = protected)
    end
    properties(Access = private)
    end
    properties(GetAccess = public,SetAccess=private)
    end
    properties(GetAccess = public,SetAccess=protected)
    end
    properties(Access = public)
        
        datafiles
        predt
        postdt
        chid
        ftid
        targets
        ft
        ftmrk
        testid
    end
    methods(Access=private)
    end
    methods(Access=protected)
    end
    methods(Access=public)
        
        
        function validatingInput(this)
            if isempty(this.ftid)
                this.ftid=[]; end
            if isempty(this.targets)
                this.targets=[1 2]; end
            if isempty(this.ft) || isempty(this.ftmrk)
                this.ft=[];
                this.ftmrk=[];
            end
            if isempty(this.testid)
                this.testid=[];
            end
            
        end
        
        function callTrainingScaffold(this)
            
            %% Calling training scaffold
            [ccobj, pp]=gen_tr(@owntrain,@ownclassify,this.datafiles,this.predt,this.postdt,...
                this.chid,this.ftid,this.targets,this.ft,this.ftmrk,this.testid);
            
            %Train classifier looping over the hyperparameter values
            %using cross-validation to select the best hyperparameter value
            function clobj=owntrain(train_examples,train_targets,val_examples,val_targets)
                fprintf('Building category classifier...\n');
                %loop over hyperparameter here
                %range of values to check for hyperparameter
                %hyper=[50,100,150,200,300,500];
                %WE WILL NOT SCAN OVER HYPERPARAMETERS BUT USE OFTEN
                %QUOTED SIZE OF THE FOREST OF 100
                %hyper1=[50,100,250,500,750,1000,2000,2500,5000,10000];
                %hyper2=[50,100,250,500,1000];
                %method={'AdaBoostM2','LPBoost','TotalBoost','RUSBoost'};
                %method={'AdaBoostM2','LPBoost','TotalBoost'};
                %hypers={hyper1,hyper2,hyper2,hyper2};
                method={'AdaBoostM2'};
                hypers={[50,100,1000]};
                ntargets=length(unique(train_targets));
                if ntargets==2
                    method{1}='AdaBoostM1';
                end
                
                %fprintf commented out due to removal of hyperparameter scanning
                %fprintf(' Selecting hyperparameter...\n');
                best_clobj=[];
                best_perf=-1;
                for method_id=1:length(method)
                    fprintf(' %s : ',method{method_id})
                    for k=hypers{method_id}
                        clobj=fitensemble(train_examples,train_targets,...
                            method{method_id},k,'Tree');
                        labels=predict(clobj,val_examples);
                        val_perf=mean(labels==val_targets);
                        fprintf(' %g,',val_perf);
                        
                        %update max
                        if val_perf>best_perf
                            best_clobj=clobj;
                            best_perf=val_perf;
                        end
                    end
                    fprintf('\b\n');
                end
                
                %select best hyperparameter
                clobj=best_clobj;
            end
            
            
            %classify using classifier model object
            function labels=ownclassify(clobj,examples)
                labels=predict(clobj,examples);
            end
            
            
        end
    end
end



