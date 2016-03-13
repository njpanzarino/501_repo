classdef H_Trans
    %H_Trans Provides helpful methods for creating and decomposing
    %Homogeneous Transformation matrices
    %   Detailed explanation goes here
    
    properties
        H = sym(eye(4));
    end
    
    properties (Dependent)
        Trans
        Rot
        Euler
    end
    
    methods
        function obj = H_Trans(varargin)
            %obj.H=eye(4);
            for i=1:length(varargin)
                obj.H=obj.H*H_Trans.single(varargin{i});
            end
        end
        
        function obj = set.Rot(obj,value)
            obj.H(1:3,1:3) = value(1:3,1:3);
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
        
        function value = getRotVel(obj,var)
           w=simplify(diff(obj.Rot,var)*obj.Rot.');
           value=[w(3,2);w(1,3);w(2,1)];
        end
        
        function value = getJacobian(obj,q)
            value = sym(zeros(6,size(q,1)));
            for i=1:size(q,1)
                value(1:3,i) = simplify(diff(obj.Trans,q(i)));
                value(4:6,i) = simplify(obj.getRotVel(q(i)));
            end 
        end
    end
    
    methods
        function  c = mtimes(a,b)
            c.H=mtimes(a.H,b.H);
        end
    end
    
    methods(Static)
        function obj = fromDH(DH)
            obj = H_Trans();
            for i = 1:size(DH,1)
                obj.H=obj.H*H_Trans.fromDH_single(DH(i,1),DH(i,2),DH(i,3),DH(i,4));
            end
        end
        
        function value = rotX(theta)
            value = [1,0,0,0;
                    0,cos(theta),-sin(theta),0;
                    0,sin(theta),cos(theta),0;
                    0,0,0,1];
        end
        function value = rotY(theta)
            value = [cos(theta),0,sin(theta),0;
                    0,1,0,0;
                    -sin(theta),0,cos(theta),0;
                    0,0,0,1];
        end
        function value = rotZ(theta)
            value = [cos(theta),-sin(theta),0,0;
                    sin(theta),cos(theta),0,0;
                    0,0,1,0;
                    0,0,0,1];
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
        
        function M = single( input_args )
        M=eye(4);
            if isequal(size(input_args),[1,3]),
                M(1:3,4) = input_args(1,:);
            elseif isequal(size(input_args),3),
                M(1:3,4) = input_args(:,1)';
            elseif isequal(size(input_args),[3,3]),
                M(1:3,1:3) = input_args(1:3,1:3);
            elseif isequal(size(input_args),[4,4]),
                M = input_args;
            end

        end
    end
end
