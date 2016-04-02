classdef Dyn_Model
    %Dyn_Model Representation of a Dynamical Model of a Serial Robotic
    %Manipulator
    %   Detailed explanation goes here
    
    properties
        g_val=9.81;         %gravity magnitude
        g_dir=[0,0,-1];     %gravity direction
        
        b %damping for each joint (tau= b*d_q)
    end
    
    properties(SetAccess = private)
        kin %Kinematic Model of a serial Robot Manipulator
        
        I = struct('val',{},'loc',{}) %Inertias relative to base frame
        Mass = struct('val',{},'loc',{}); %Mass value and location relative to base frame
        
        k %stiffness for each joint 
        
        tau %symbolic represantaion of joint control values, used in symbolic calculation of forward_dynamics
        t=sym('t');
        
        % M(q)*dd_q + V(q,d_q) + G(q) = tau
        sym_M %Inertia Matrix  :  M(q)
        sym_V %Coriolis Vector :  V(q,d_q)
        sym_G %Gravity Vector  :  G(q)
        
        sym_invM %M^-1
        
        func_M
        func_V
        func_G
        func_invM
        
        func_fDyn
        func_iDyn
    end
    
    properties(Dependent)
        g %gravity vector (combined magnitude and direction)
    end
    
    properties(Dependent, SetAccess=private)
        q    %joint variables
        d_q  %1st time derivative of joint variables
        dd_q %2nd time derivative of joint variables
        
        q_t
        d_q_t
        dd_q_t
    end
    
    properties(Access=private)
        val_q    %joint variables
        val_d_q  %1st time derivative of joint variables
        val_dd_q %2nd time derivative of joint variables
        
        val_q_t    
        val_d_q_t  
        val_dd_q_t 
    end
    
    methods
        function obj = Dyn_Model(kin)
            if nargin>0
                obj=Dyn_Model.fromKin_Model(kin);
            end
        end
        
        function equ = diff(obj,equ)
            equ=obj.subsQ(diff(obj.subsT(equ),obj.t));
        end
        
        function obj = clearMass(obj)
            obj.Mass = struct('val',[],'loc',[]);
        end
        function obj = addMass(obj,value,location,frame)
            location=reshape(location,numel(location),1);
            if nargin>3
                location=obj.kin.T(0,frame).H*[location;1];
                location=location(1:3);
            end
            
            i=size(obj.Mass,2)+1;
            
            obj.Mass(i).val=value;
            obj.Mass(i).loc=location;
        end
        
        function obj = clearI(obj)
            obj.I = struct('val',[],'loc',[]);
        end
        function obj = addI(obj,value,rot,frame)
            if ~isequal(size(value),[3,3])
                v=value;
                value=sym(zeros(3,3));
                value(3,3)=v;
            end
            
            if nargin>3
                rot=obj.kin.T(0,frame).Rot*rot;
            end
            
            i=size(obj.I,2)+1;
            
            obj.I(i).val=value;
            obj.I(i).loc=rot;
        end
        
        function obj = add(obj,T_form,m,I,frame)
            if exist('m','var')>0
                if exist('frame','var')>0
                    obj=obj.addMass(m,T_form.Trans,frame);
                else
                    obj=obj.addMass(m,T_form.Trans);
                end
            end
            if exist('I','var')>0
                if exist('frame','var')>0
                    obj=obj.addI(I,T_form.Rot,frame);
                else
                    obj=obj.addI(I,T_form.Rot);
                end
                
            end
        end
        function obj = clear(obj)
            obj=obj.clearMass;
            obj=obj.clearI;
        end
        
        function val=inverse_dyn(obj,q,d_q,dd_q)
            switch nargin
                case 1
                    val=obj.func_iDyn(obj.q,obj.d_q,obj.dd_q);
                case 2
                    val=obj.func_iDyn(q,zeros(size(obj.d_q)),zeros(size(obj.dd_q)));
                case 3
                    val=obj.func_iDyn(q,d_q,zeros(size(obj.dd_q)));
                case 4
                    val=obj.func_iDyn(q,d_q,dd_q);
            end
%             val=zeros(size(obj.q));
%             
%             if nargin<3
%                 d_q=zeros(size(obj.q));
%             end
%             if nargin<4
%                 dd_q=zeros(size(obj.q));
%             else
%                 val=val+obj.M(q)*dd_q;
%             end
%             
%             val=val+obj.V(q,d_q)+obj.G(q)+obj.b.*d_q;
%             val=vpa(val);
        end
        function dd_q=forward_dyn(obj,q,d_q,tau)
            switch nargin
                case 1
                    dd_q=obj.func_fDyn(obj.q,obj.d_q,obj.tau);
                case 2
                    dd_q=obj.func_fDyn(q,zeros(size(obj.d_q)),zeros(size(obj.tau)));
                case 3
                    dd_q=obj.func_fDyn(q,d_q,zeros(size(obj.tau)));
                case 4
                    dd_q=obj.func_fDyn(q,d_q,tau);
            end
            
%             if nargin<3
%                 d_q=zeros(size(obj.q));
%             end
%             if nargin<4
%                 tau=zeros(size(obj.q));
%             end
%             
%             dd_q=obj.invM(q)*(tau-obj.V(q,d_q)-obj.G(q)-obj.b.*d_q);
%             dd_q=vpa(dd_q);
        end

        function val = M(obj,q)
            if nargin<2
                val=obj.sym_M;
            else
                val=obj.func_M(q);
            end
        end
        function val = V(obj,q,d_q)
            if nargin<2
                val=obj.sym_V;
            elseif nargin<3
                val=obj.func_V(q,obj.d_q);
            else
                val=obj.func_V(q,d_q);
            end
        end
        function val = G(obj,q)
            if nargin<2
                val=obj.sym_G;
            else
                val=obj.func_G(q);
            end
        end
        
        function val = invM(obj,q)
            if nargin<2
                val=obj.sym_invM;
            else
                val=obj.func_invM(q);
            end
        end
        
        function obj = calculateDynamics(obj)
            K=0;
            
            if size(obj.Mass,2)>0
                temp=cell(size(obj.Mass,2),1);
                
                [temp{:}]=obj.Mass.loc;
                x=sym(zeros(size(obj.Mass,2),size(temp{1},1)));
                for i=1:numel(temp)
                    x(i,:)=temp{i}.';
                end

                [temp{:}]=obj.Mass.val;
                m=sym(zeros(size(obj.Mass,2),1));
                for i=1:numel(temp)
                    m(i)=temp{i};
                end
            
                %Can replace this with Jacobian calculation?
                v=obj.diff(x);
            
                Km=(1/2).*m.'*dot(v,v,2);
                K=K+sum(Km);
            end
            
            if size(obj.I,2)>0
                temp=cell(size(obj.I,2),1);
                
                [temp{:}]=obj.I.val;
                I=temp;
                [temp{:}]=obj.I.loc;
                r=temp;

                w=sym(zeros(size(obj.I,2),3));
                for i=1:numel(temp)
                    %Can replace this with Jacobian calculation?
                    w(i,:)=obj.subsQ(H_Trans(obj.subsT(r{i})).getRotVel(obj.t)).';
                end

                It=cell(size(obj.I,2),1);
                for i=1:numel(temp)
                    It{i}=r{i}.'*I{i}*r{i};
                end
                
                Kr=sym(zeros(size(obj.I,2),1));
                for i=1:size(obj.I,2)
                    Kr(i)=w(i,:)*It{i}*w(i,:).';
                end
                Kr=(1/2).*Kr;
                K=K+sum(Kr);
            end
            
            obj.g_dir=reshape(obj.g_dir,1,numel(obj.g_dir));
            g=repmat(-obj.g_dir,size(x,1),1);
            h=dot(x,g,2);
            
            P=obj.g_val.*m.*h;
            P=sum(P);
            
            L=K-P;
            E_L=sym(zeros(size(obj.q)));
            for i=1:numel(obj.q)
                E_L(i)=obj.diff(diff(L,obj.d_q(i)))-diff(L,obj.q(i));
            end
            E_L=simplify(vpa(E_L));
            
            %Just get the matrices and done
            obj.sym_G=subs(E_L,[obj.dd_q,obj.d_q],[zeros(size(obj.dd_q)),zeros(size(obj.d_q))]);
            obj.sym_V=subs(E_L,obj.dd_q,zeros(size(obj.dd_q)))-obj.sym_G;
            
            obj.sym_M=E_L-obj.sym_V-obj.sym_G;
            [obj.sym_M,~]=equationsToMatrix(obj.sym_M,obj.dd_q);
            
            obj.sym_invM=inv(obj.sym_M);
            
            obj.sym_G=simplify(obj.sym_G);
            obj.sym_V=simplify(obj.sym_V);

            obj.func_M=createFunction(obj.sym_M,obj.q);
            obj.func_V=createFunction(obj.sym_V,{obj.q,obj.d_q});
            obj.func_G=createFunction(obj.sym_G,obj.q);
            obj.func_invM=createFunction(obj.sym_invM,obj.q);
            
            obj.func_iDyn=createFunction(E_L+obj.b.*obj.d_q,...
                {obj.q,obj.d_q,obj.dd_q});
            obj.func_fDyn=createFunction(obj.invM*(obj.tau-obj.V-obj.G-obj.b.*obj.d_q),...
                {obj.q,obj.d_q,obj.tau});
        end
        
        function [ode_func,d_func] = ODE(obj,sym_q,c_func,noise_func)
            n=nargin;
            if n<4
                noise_func=[];
            end
            
            d_func=desired;
            ode_func=CreateODE(d_func,control,@response,noise_func);

            function d=desired
                desired_t(:,1)=sym_q;
                desired_t(:,2)=diff(sym_q,obj.t);
                desired_t(:,3)=diff(desired_t(:,2),obj.t);

                d=matlabFunction(desired_t,'Vars',obj.t);
            end

            function c = control
                if n<3 || isempty(c_func)
                    c_func = Controller.ComputedTorque(obj);
                end
                c=c_func;
            end

            function r = response(actual,tau)
                r(:,1)=actual(:,2);
                r(:,2)=obj.forward_dyn(actual(:,1),actual(:,2),tau);
            end
        end
        
        function simulate(obj,ode_args,t_span,q0,ode_options,draw_options)
            if nargin<6
                ode_options=[];
            end
            sym_q=ode_args{1};
            
            ode=obj.ODE(ode_args{:});

            disp('Beginning Simulation');

            [T,Y]=ode45(ode,t_span,reshape(q0,numel(q0),1),ode_options);

            disp('Simulation Complete');

            a=[Y(:,1),Y(:,2)].';
            obj.kin.simulate(a,draw_options{:});
            
            for i=1:size(sym_q)
                d_func=matlabFunction(sym_q(i));
                figure('Name',strcat('q',num2str(i)));
                plot(T, Y(:,i),'r-');
                hold on
                plot(T,d(d_func,T),'b-');
            end
             
%             figure('Name','Input');
%             plot(times, torques(1:size(times,1),1),'-' );
%             hold on
%             plot(times, torques(1:size(times,1),2),'r--');
            
            function vals = d(d_func,t_list)
                if nargin(d_func)==0
                    vals=d_func()*ones(size(t_list,1),1);
                else
                    vals=d_func(t_list);
                end
            end
        end
    end
    
    methods
        function obj = set.g(obj,g)
            obj.g_val=norm(g);
            obj.g_dir=g/obj.g_val;
        end
        function value = get.g(obj)
            value=obj.g_val.*obj.g_dir;
        end
        
        function obj = set.q(obj,q)
            n=size(q);
            
            obj.val_q=q;
            obj.val_d_q=sym('d_q',n);
            obj.val_dd_q=sym('dd_q',n);
            
            obj.val_q_t=sym('q_t',n);
            obj.val_d_q_t=sym('d_q_t',n);
            obj.val_dd_q_t=sym('dd_q_t',n);
            
            for i=1:n
                obj.val_d_q(i)=sym(strcat('d_',char(q(i))),'real');
                obj.val_dd_q(i)=sym(strcat('dd_',char(q(i))),'real');
                
                obj.val_q_t(i) = sym(strcat(char(q(i)),'(',char(obj.t),')'),'real');
                obj.val_d_q_t(i) = diff(obj.val_q_t(i),obj.t);
                obj.val_dd_q_t(i) = diff(obj.val_q_t(i),obj.t,2);
            end
        end
        function value = get.q(obj)
            value=obj.val_q;
        end
        function value = get.d_q(obj)
            value=obj.val_d_q;
        end
        function value = get.dd_q(obj)
            value=obj.val_dd_q;
        end
        
        function value = get.q_t(obj)
            value=obj.val_q_t;
        end
        function value = get.d_q_t(obj)
            value=obj.val_d_q_t;
        end
        function value = get.dd_q_t(obj)
            value=obj.val_dd_q_t;
        end
    end
    
    methods(Static)
        function obj = fromKin_Model(model)
            obj = Dyn_Model;
			obj.kin=model;
            obj.q=obj.kin.q;
            obj.tau=sym('tau',size(obj.q));
            
            obj.b=zeros(size(obj.q));
            
        end
    end
    
    methods(Access=public)
        function equ=subsT(obj,equ)
            equ=subs(equ,obj.q,obj.q_t);
            equ=subs(equ,obj.d_q,obj.d_q_t);
            equ=subs(equ,obj.dd_q,obj.dd_q_t);
        end
        
        function equ=subsQ(obj,equ)
            equ=subs(equ,obj.dd_q_t,obj.dd_q);
            equ=subs(equ,obj.d_q_t,obj.d_q);
            equ=subs(equ,obj.q_t,obj.q);
        end
    end
end

