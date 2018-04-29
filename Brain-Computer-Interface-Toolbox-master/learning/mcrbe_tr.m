classdef mcrbe_tr <handle
    
    
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
                dst=dist(train_examples');
                dst(dst==0)=Inf;
                nndst=min(dst,[],2);
                normspread=mean(nndst)/2;
                %range of values to check for hyperparameter
                hyper=normspread*[0.5,1.0,2.0,3.0,4.0,6.0,12.0];
                val_performance=zeros(size(hyper));
                val_classifier=cell(size(hyper));
                
                %note - direct RBFN implementation against targets doesn't work,
                % instead we try binary encoding/decoding of the states
                %comment out fprintf if remove hyperparameter scan
                fprintf(' Selecting hyperparameter...\n');
                cnt=1;
                all_targets=unique(train_targets);
                rb_train=zeros(length(all_targets),length(train_targets));
                for k=1:length(all_targets)
                    rb_train(k,:)=train_targets==k;
                end
                for k=hyper
                    clobj=newrbe(train_examples',rb_train,k);
                    rb_labels=sim(clobj,val_examples');
                    [~,rb_idlabels]=max(rb_labels,[],1);
                    labels=all_targets(rb_idlabels);
                    
                    val_classifier{cnt}={clobj,all_targets};
                    val_performance(cnt)=mean(labels==val_targets);
                    cnt=cnt+1;
                    
                    fprintf(' %g,',val_performance(cnt-1));
                end
                fprintf('\b\n');
                
                %select best hyperparameter
                [~, best_xval_index]=max(val_performance);
                
                %fprintf(' Selected hyperparameter %g...\n',hyper(best_xval_index));
                clobj=val_classifier{best_xval_index};
            end
            
            
            %classify using classifier model object
            function labels=ownclassify(clobj,examples)
                rb_labels=sim(clobj{1},examples');
                [~,rb_idlabels]=max(rb_labels,[],1);
                labels=clobj{2}(rb_idlabels);
            end
            
        end
        
        
    end
end




