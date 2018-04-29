classdef mcrf_tr <handle
    
    
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
                hyper=100;
                val_performance=zeros(size(hyper));
                val_classifier=cell(size(hyper));
                
                %fprintf commented out due to removal of hyperparameter scanning
                %fprintf(' Selecting hyperparameter...\n');
                cnt=1;
                for k=hyper
                    clobj=TreeBagger(k,train_examples,train_targets);
                    labels=predict(clobj,val_examples);
                    
                    %need to do this additionally for TreeBagger
                    labels=cellfun(@str2num,labels);
                    
                    val_classifier{cnt}=clobj;
                    val_performance(cnt)=mean(labels==val_targets);
                    cnt=cnt+1;
                    
                    %fprintf(' %g,',val_performance(cnt-1));
                end
                %fprintf('\b\n');
                
                %select best hyperparameter
                [~, best_xval_index]=max(val_performance);
                
                %fprintf(' Selected hyperparameter %g...\n',hyper(best_xval_index));
                clobj=val_classifier{best_xval_index};
            end
            
            
            %classify using classifier model object
            function labels=ownclassify(clobj,examples)
                labels=predict(clobj,examples);
                
                %need to do this additionally for TreeBagger
                labels=cellfun(@str2num,labels);
            end
            
        end
        
    end
end