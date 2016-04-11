classdef H_Trans
    %H_Trans Provides helpful methods for creating and decomposing Homogeneous Transformation matrices
    %   Detailed explanation goes here
    
    properties
        H = sym(eye(4));
    end
    
    properties (Dependent)
        Trans
        Rot
        Euler   %ZYX Euler Angles
        Wrench
        Column
    end
    
    properties (Access=private)
        sym_Euler
    end
    
    methods
        function obj = H_Trans(varargin)
			if nargin>0
				obj.H=H_Trans.single(varargin{1});
				if nargin>1
					for i=2:length(varargin)
						obj.H=obj.H*H_Trans.single(varargin{i});
					end
				end
			end
        end
        
        function obj = set.Rot(obj,value)
            obj.H(1:3,1:3) = value(1:3,1:3);
            obj.sym_Euler=[];
        end
        function value = get.Rot(obj)
            value = obj.H(1:3,1:3);
        end
        
        function obj = set.Trans(obj,value)
            obj.H(1:3,4) = value;
        end
        function value = get.Trans(obj)
            value = obj.H(1:3,4);
        end
		
		function obj = set.Euler(obj,value)
            T=(H_Trans.rotZ(value(3))*H_Trans.rotY(value(2))*H_Trans.rotX(value(1)));
            obj.Rot=T.Rot;
            obj.sym_Euler=value;
        end
        function value = get.Euler(obj)
            if isempty(obj.sym_Euler)
                R=obj.Rot;
                value=[atan2(R(3,2),R(3,3));
                       atan2(-R(1,3),sqrt(R(3,2)^2+R(3,3)^2));
                       atan2(R(2,1),R(1,1))];
            else
                value=obj.sym_Euler;
            end
            
%             v1=simplify(R(3,2)/R(3,3));
%             [n1,d1]=numden(v1);
%             
%             v2=simplify(R(2,1)/R(1,1));
%             [n2,d2]=numden(v2);
%             
%             value=[atan2(n1,d1);
%                    asin(-R(3,1));
%                    atan2(n2,d2)];
             
        end
        
        function obj = set.Wrench(obj,value)
            obj.Trans=value(1:3);
            obj.Euler=value(4:6);
        end
        function value = get.Wrench(obj)
            value=[obj.Trans;obj.Euler];
        end
        
        function obj = set.Column(obj,value)
            obj.H=reshape(value,4,4);
        end
        function value = get.Column(obj)
            value=reshape(obj.H,16,1);
        end
        
        %w=B*diff(euler)
        function value = B(obj)
            t1=sym('t1','real');
            t2=sym('t2','real');
            t3=sym('t3','real');
            H_=H_Trans();
            H_.Euler=[t1;t2;t3];
            
            B_=[H_.getRotVel(t3),...
                H_.getRotVel(t2),...
                H_.getRotVel(t1)];
            value=subs(B_,[t1;t2;t3],obj.Euler);
        end
        %diff(euler)=inv_B*w
        function value = inv_B(obj)
            t1=sym('t1','real');
            t2=sym('t2','real');
            t3=sym('t3','real');
            H_=H_Trans();
            H_.Euler=[t1;t2;t3];
            
            B_=[H_.getRotVel(t3),...
                H_.getRotVel(t2),...
                H_.getRotVel(t1)];
            value=subs(inv(B_),[t1;t2;t3],obj.Euler);
        end
        
        function value = getRotVel(obj,var)
           w=simplify(diff(obj.Rot,var)*obj.Rot.');
           value=[w(3,2);w(1,3);w(2,1)];
        end
		
        function [Jg,Ja] = getJacobians(obj,q)
            Jg= sym(zeros(6,size(q,1)));
            Ja= Jg;
            w=obj.Wrench;
            for i=1:size(q,1)
                v=diff(w(1:3),q(i));
                Jg(1:3,i) = v ;
                Ja(1:3,i) = v ;
                Jg(4:6,i) = obj.getRotVel(q(i));
                Ja(4:6,i) = diff(w(4:6),q(i));
            end 
            Jg=simplify(Jg);
            Ja=simplify(Ja);
        end
        
        function value = getJacobian(obj,q)
            value = sym(zeros(6,size(q,1)));
            for i=1:size(q,1)
                value(1:3,i) = diff(obj.Trans,q(i));
                value(4:6,i) = obj.getRotVel(q(i));
            end 
            value=simplify(value);
        end
        
        function Jg = JaToJg(obj,Ja)
            
            Ba=[eye(3),zeros(3);zeros(3),obj.B];
            
            Jg=Ba*Ja;
        end
        function Ja = JgToJa(obj,Jg)
            inv_Ba=[eye(3),zeros(3);zeros(3),obj.inv_B];
            
            Ja=inv_Ba*Jg;
        end
        
        function value = getAnalyticJacobian(obj,q)
            w=obj.Wrench;
            value = sym(zeros(6,size(q,1)));
            for i=1:size(q,1)
                value(1:6,i) = diff(w,q(i));
            end 
            value=simplify(value);
        end
        
        function func = getFunction(obj,input)
            expr=obj.H;
            func=createFunction(expr,input);
        end
        
        function obj = inv(obj)
			R=obj.Rot.';
			obj.H = [ R  -R*obj.Trans
					 0 0 0       1     ];
		end
    end
    
    methods
        function  c = mtimes(a,b)
            c=H_Trans(mtimes(a.H,b.H));
        end
        
        function  c = mrdivide(a,b)
            a=a.inv();
            c=H_Trans(mtimes(b.H,a.H));
        end
        
        function  c = mldivide(a,b)
            a=a.inv();
            c=H_Trans(mtimes(a.H,b.H));
        end
        
        function draw(obj,scale,label,ax,plotArgs)
            
            if nargin<2 || isempty(scale)
                scale=1;
            end
            
            if nargin<4 || isempty(ax)
                ax=gca;
            end
            
            if nargin<5 || isempty(plotArgs)
                plotArgs={};
            end
            
            p=double(obj.Trans);
            r=double(obj.Rot);
            
            plot3(p(1), p(2), p(3));
  
            hchek = ishold;
            hold on

            if (isequal(zeros(3,1), p)) && (isequal(eye(3),r)),
            % use gray for the base frame
%                 plot3(ax,[p(1);p(1)+scale*r(1,1)],[p(2);p(2)+scale*r(2,1)],[p(3);p(3)+scale*r(3,1)],'Color','k','linewidth',2,plotArgs{:});
%                 plot3(ax,[p(1);p(1)+scale*r(1,2)],[p(2);p(2)+scale*r(2,2)],[p(3);p(3)+scale*r(3,2)],'Color','k','linewidth',2,plotArgs{:});
%                 plot3(ax,[p(1);p(1)+scale*r(1,3)],[p(2);p(2)+scale*r(2,3)],[p(3);p(3)+scale*r(3,3)],'Color','k','linewidth',2,plotArgs{:});

                h=plot3(ax,[p(1);p(1)+scale*r(1,1)],[p(2);p(2)+scale*r(2,1)],[p(3);p(3)+scale*r(3,1)],'k',...
                    [p(1);p(1)+scale*r(1,2)],[p(2);p(2)+scale*r(2,2)],[p(3);p(3)+scale*r(3,2)],'k',...
                    [p(1);p(1)+scale*r(1,3)],[p(2);p(2)+scale*r(2,3)],[p(3);p(3)+scale*r(3,3)],'k',plotArgs{:});
            else    
%                 plot3(ax,[p(1);p(1)+scale*r(1,1)],[p(2);p(2)+scale*r(2,1)],[p(3);p(3)+scale*r(3,1)],'Color','r','linewidth',2,plotArgs{:});
%                 plot3(ax,[p(1);p(1)+scale*r(1,2)],[p(2);p(2)+scale*r(2,2)],[p(3);p(3)+scale*r(3,2)],'Color','g','linewidth',2,plotArgs{:});
%                 plot3(ax,[p(1);p(1)+scale*r(1,3)],[p(2);p(2)+scale*r(2,3)],[p(3);p(3)+scale*r(3,3)],'Color','b','linewidth',2,plotArgs{:});

                 h=plot3(ax,[p(1);p(1)+scale*r(1,1)],[p(2);p(2)+scale*r(2,1)],[p(3);p(3)+scale*r(3,1)],'r',...
                    [p(1);p(1)+scale*r(1,2)],[p(2);p(2)+scale*r(2,2)],[p(3);p(3)+scale*r(3,2)],'g',...
                    [p(1);p(1)+scale*r(1,3)],[p(2);p(2)+scale*r(2,3)],[p(3);p(3)+scale*r(3,3)],'b',plotArgs{:});
            end

            if nargin>2&&~isempty(label)
                t=text(p(1)-sum(r(1,:))*0.05,p(2)-sum(r(2,:))*0.07,p(3)-sum(r(3,:))*0.07,strcat('F',label));
                t.Parent=ax;
                t=text(p(1)+scale*r(1,1)+sum(r(1,:))*0.02,p(2)+scale*r(2,1)+sum(r(2,:))*0.05,p(3)+scale*r(3,1)+sum(r(3,:))*0.05,strcat('x',label));
                t.Parent=ax;
                t=text(p(1)+scale*r(1,2)+sum(r(1,:))*0.02,p(2)+scale*r(2,2)+sum(r(2,:))*0.05,p(3)+scale*r(3,2)+sum(r(3,:))*0.05,strcat('y',label));
                t.Parent=ax;
                t=text(p(1)+scale*r(1,3)+sum(r(1,:))*0.02,p(2)+scale*r(2,3)+sum(r(2,:))*0.05,p(3)+scale*r(3,3)+sum(r(3,:))*0.05,strcat('z',label));
                t.Parent=ax;
            end

            if hchek == 0
                hold off
            end
        end
    end
    
    methods(Static)
        function obj = fromDH(DH)
            obj = H_Trans();
            for i = 1:size(DH,1)
                obj.H=obj.H*H_Trans.fromDH_single(DH(i,1),DH(i,2),DH(i,3),DH(i,4));
            end
            obj.H=simplify(vpa(obj.H));
        end
        
        function obj = rotX(theta)
            obj = H_Trans([1,0,0,0;
                    0,cos(theta),-sin(theta),0;
                    0,sin(theta),cos(theta),0;
                    0,0,0,1]);
        end
        function obj = rotY(theta)
            obj = H_Trans([cos(theta),0,sin(theta),0;
                    0,1,0,0;
                    -sin(theta),0,cos(theta),0;
                    0,0,0,1]);
        end
        function obj = rotZ(theta)
            obj = H_Trans([cos(theta),-sin(theta),0,0;
                    sin(theta),cos(theta),0,0;
                    0,0,1,0;
                    0,0,0,1]);
        end
        
    end
    
    methods (Static,Access=private)
        
        function [output_args] = fromDH_single( theta, d, a, alpha )
        theta=sym(theta);d=sym(d);a=sym(a);alpha=sym(alpha);
        output_args=[cos(theta),-sin(theta)*cos(alpha),sin(theta)*sin(alpha),a*cos(theta);...
            sin(theta),cos(theta)*cos(alpha),-cos(theta)*sin(alpha),a*sin(theta);...
            0,sin(alpha),cos(alpha),d;...
            0,0,0,1];
        end
        
        function M = single( input )
        
            if isequal(size(input),[4,4]),
                M = input;
			elseif isequal(size(input),[3,3])
                M=sym(eye(4));
                M(1:3,1:3) = input(1:3,1:3);
			elseif isequal(size(input),[1,3])
                M=sym(eye(4));
                M(1:3,4) = input(1,:);
            elseif isequal(size(input),[3,1])
                M=sym(eye(4));
                M(1:3,4) = input(:,1).';
            elseif isequal(size(input),[6,1])
                M=H_Trans;
                M.Wrench=input;
                M=M.H;
            elseif isequal(size(input),[16,1])
                M=reshape(input,[4,4]);
            end
        end
    end
end

