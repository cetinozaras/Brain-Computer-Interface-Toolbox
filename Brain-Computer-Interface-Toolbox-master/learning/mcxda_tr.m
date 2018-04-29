classdef mcxda_tr <handle
    
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
        ctype
        
    end
    methods(Access=private)
    end
    methods(Access=protected)
    end
    methods(Access=public)
        
        
        %% Validating input parameters
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
            if isempty(this.ctype)
                this.ctype='linear';
            end
        end
        %% Calling training scaffold
        %function to be passed to gen_tr scaffold should only have the signature
        % function classifierObject=funcTrain(trainExamples,trainTargets,...
        %  validationExamples,validationTargets)
        function callTrainingScaffold(this)
            func=@(train_examples,train_targets,val_examples,val_targets) ...
                owntrain(train_examples,train_targets,val_examples,val_targets,this.ctype);
            
            [ccobj, pp]=gen_tr(func,@ownclassify,this.datafiles,this.predt,this.postdt,...
                this.chid,this.ftid,this.targets,this.ft,this.ftmrk,this.testid);
            
            function clobj=owntrain(train_examples,train_targets,val_examples,val_targets,cftype)
                clobj=[];
                clobj.cfexamples=train_examples;
                clobj.cftargets=train_targets;
                clobj.cftype=cftype;
            end
            
            
            %classify using SVM model object
            function labels=ownclassify(clobj,xeegsamples)
                labels=classify(xeegsamples,clobj.cfexamples,clobj.cftargets,clobj.cftype);
            end
            
        end
        
    end
end

