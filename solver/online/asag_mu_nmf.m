function [x, infos] = asag_mu_nmf(V, rank, in_options)
% Asymmetric stochastic averaging gradient multiplicative update for non-negative matrix factorization (ASGA-MU-NMF) algorithm.
%
% Inputs:
%       matrix      V
%       rank        rank
%       options     options
% Output:
%       w           solution of w
%       infos       information
%
% References:
%       Romain Serizel, Slim Essid and Ga?l Richard,
%       "Mini-batch stochastic approaches for accelerated multiplicative updates 
%       in nonnegative matrix factorisation with beta-divergence,"
%       IEEE 26th International Workshop on Machine Learning for Signal Processing (MLSP), 
%       MLSP2016.
%
%   
% This file is part of NMFLibrary.
%
% Created by H.Kasai on March. 22, 2017
%
% Change log: 
%
%       Oct. 27, 2017 (Hiroyuki Kasai): Fixed algorithm. 
%
%       May. 20, 2019 (Hiroyuki Kasai): Added initialization module.
%
%       Jul. 12, 2022 (Hiroyuki Kasai): Modified code structures.
%


    % set dimensions and samples
    [m, n] = size(V);
 
    % set local options
    local_options = [];
    local_options.lambda = 1;
    
    % check input options
    if ~exist('in_options', 'var') || isempty(in_options)
        in_options = struct();
    end      
    % merge options
    options = mergeOptions(get_nmf_default_options(), local_options);   
    options = mergeOptions(options, in_options); 
    
    % initialize factors
    init_options = options;
    [init_factors, ~] = generate_init_factors(V, rank, init_options);    
    Wt = init_factors.W;
    H = init_factors.H; 

    % initialize
    method_name = 'ASAG-MU-NMF';    
    epoch = 0;    
    grad_calc_count = 0;

    if options.verbose > 0
        fprintf('# %s: started ...\n', method_name);           
    end    
    
    % permute samples
    if options.permute_on
        perm_idx = randperm(n);
    else
        perm_idx = 1:n;
    end  
    
    V = V(:,perm_idx);
    H = H(:,perm_idx);   
    
    % prepare Delta_minus and Delta_plus
    Delta_minus = zeros(m, rank);
    Delta_plus = zeros(m, rank); 
    
    % store initial info
    clear infos;
    [infos, f_val, optgap] = store_nmf_info(V, Wt, H, [], options, [], epoch, grad_calc_count, 0);
    
    if options.verbose > 1
        fprintf('%s: Epoch = 0000, cost = %.16e, optgap = %.4e\n', method_name, f_val, optgap); 
    end     
         
    % set start time
    start_time = tic();
    
    % main outer loop
    while true
        
        % check stop condition
        [stop_flag, reason, max_reached_flag] = check_stop_condition(epoch, infos, options);
        if stop_flag
            display_stop_reason(epoch, infos, options, method_name, reason, max_reached_flag);
            break;
        end         
        
        cnt = 0;
        % main inner loop
        for t = 1 : options.batch_size : n - 1
            cnt = cnt + 1;

            % retrieve vt and ht
            vt = V(:,t:t+options.batch_size-1);
            ht = H(:,t:t+options.batch_size-1);
            
            % uddate ht
            ht = ht .* (Wt.' * vt) ./ (Wt.' * (Wt * ht));
            ht = ht + (ht<eps) .* eps; 

            % update Delta_minus and Delta_plus
            Delta_minus = (1-options.lambda) * Delta_minus + options.lambda * vt * ht';
            Delta_plus = (1-options.lambda) * Delta_plus + options.lambda * Wt * (ht * ht');

            % update W
            Wt = Wt .* (Delta_minus ./Delta_plus);            
            Wt = Wt + (Wt<eps) .* eps;
            
            % store new h
            H(:,t:t+options.batch_size-1) = ht;  
            
            grad_calc_count = grad_calc_count + m * options.batch_size;
        end
        
        % measure elapsed time
        elapsed_time = toc(start_time);        

        % update epoch
        epoch = epoch + 1;          
        
        % store info
        infos = store_nmf_info(V, Wt, H, [], options, infos, epoch, grad_calc_count, elapsed_time);  
        
        % display info
        display_info(method_name, epoch, infos, options);
       
    end

    
    x.W = Wt;
    x.H(:,perm_idx) = H;

end