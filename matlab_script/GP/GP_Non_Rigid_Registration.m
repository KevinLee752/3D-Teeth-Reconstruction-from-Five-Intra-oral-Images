classdef GP_Non_Rigid_Registration < handle
    % 使用高斯过程进行非刚性配准，并寻找对应点对

    properties
        % use gaussian kernel g(x',x) = s * exp(-||x'-x||^2 / sigma^2)
        s;
        sigma;
        srcX;
        N; % point num in source pointcloud
        d; % point dimension
        targetYs;
        n_sample; % num of sample in targetYs
        GP_Mu; % mean deformation in GP, default value = 0
        
        n; % number of term used in low-rank approx. of GP
        eta; % normalization factor of alpha
        lambda_n; % the first n eigen values
        phi_n; % the first n eigen vectors (approx. of eigen functions)
        deformedXs;
        approx_percentage; % accumulative explained variance of low-rank approx. of GP

    end

    methods
        function obj = GP_Non_Rigid_Registration(np_srcX, np_targetYs, s, sigma, n, eta)
            obj.s = double(s);
            obj.sigma = double(sigma);
            obj.srcX = double(np_srcX'); % size=(3,1500)
            [obj.d, obj.N] = size(obj.srcX);

            obj.targetYs = {};
            obj.n_sample = length(np_targetYs);
            for i = 1:obj.n_sample
                obj.targetYs{i} = double(np_targetYs{i})';
            end

            obj.GP_Mu = zeros([obj.d*obj.N,1]); % size=(4500,1)
            obj.n = uint32(n);
            obj.eta = double(eta);
            obj.lambda_n = zeros([n,1]); % size=(n,1)
            obj.phi_n = zeros([obj.d*obj.N,n]); % size=(4500,n)
            obj.deformedXs = zeros([obj.d, obj.N, obj.n_sample]);

            obj.approx_percentage = 0;
        end

        function compute_EigVals_EigFuncs_of_GP_K(obj)
            % Nyström Method 计算矩阵GP_K的特征值，特征向量用于近似GP_K的特征值和特征函数 
            % low-rank approx. of GP
            D_X = GP_Non_Rigid_Registration.squared_distance_matrix(obj.srcX, obj.srcX);
            GP_K = obj.s * kron(exp( -D_X / obj.sigma^2),eye(obj.d));
            [phi, lambda] = eig(GP_K); % 矩阵特征值分解
            [lambda_sort,index] = sort(diag(lambda), 'descend');
            phi_sort = phi(:,index); % 对特征值降序排列，提取特征函数
            
            obj.phi_n = phi_sort(:,1:obj.n);
            obj.lambda_n = lambda_sort(1:obj.n);
            obj.approx_percentage = sum(obj.lambda_n)/sum(lambda_sort);
            fprintf("Finish computing eigVals and eigVecs of GP Registration\n");
            fprintf("Low-rank approx. percentage of GP: %.4f \n", obj.approx_percentage);
        end

        function loss = registration_loss(obj, alpha, Yidx)
            normalization = obj.eta * sum(alpha.^2);
            GP = obj.phi_n * (alpha.*obj.lambda_n);% + obj.GP_Mu;
            X_deformed = obj.srcX + reshape(GP, [obj.d,obj.N]);
            chamfer_dist = GP_Non_Rigid_Registration.chamferDistance(X_deformed, obj.targetYs{Yidx});
            loss = chamfer_dist + normalization;
        end

        function updateDeformedXs(obj, alpha, idx)
            GP = obj.phi_n * (alpha.*obj.lambda_n);% + obj.GP_Mu;
            obj.deformedXs(:,:,idx) = obj.srcX + reshape(GP, [obj.d,obj.N]);
        end
    end

    methods(Static)
        function D = squared_distance_matrix(X1, X2)
            [~,n1] = size(X1);
            [~,n2] = size(X2);
            D = zeros([n1,n2]);
            for i = 1:n2
                D(:,i) = sum((X1-X2(:,i)).^2, 1)';
            end
        end

        function cd = chamferDistance(X1,X2)
            D = GP_Non_Rigid_Registration.squared_distance_matrix(X1,X2);
            cd = mean(min(D,[],1)) + mean(min(D,[],2));
        end
    end
end