function [x, infos] = sparse_mu_v_nmf(V, rank, in_options)
% Sparse Multiplicative upates (MU) for non-negative matrix factorization (Sparse-MU-V).
%
% The problem of interest is defined as
%
%       min  D(V||W*H) + lambda*phi(H),
%       where 
%       {V, W, H} >= 0, and phi(H) is a sparsity penalty defined in the reference below;
%
% Given a non-negative matrix V, factorized non-negative matrices {W, H} are calculated.
%
%
% Inputs:
%       V           : (m x n) non-negative matrix to factorize
%       rank        : rank
%       in_options 
%
%
% Output:
%       x           : non-negative matrix solution, i.e., x.W: (m x rank), x.H: (rank x n)
%       infos       : log information
%           epoch   : iteration nuber
%           cost    : objective function value
%           optgap  : optimality gap
%           time    : elapsed time
%           grad_calc_count : number of sampled data elements (gradient calculations)
%
% References
%       T. Virtanen,
%       "Monaural sound source separation by non-negative factorization with temporal 
%       continuity and sparseness criteria,"
%       IEEE Transactions on Audio, Speech, and Language Processing, vol.15, no.3, 2007.
%   
%
% This file is part of NMFLibrary.
%
% Originally created by G.Grindlay (grindlay@ee.columbia.edu) on Jan. 14, 2010
%
% Modified by H.Kasai on Jul. 23, 2018
%
% Change log: 
%
%       May. 20, 2019 (Hiroyuki Kasai): Added initialization module.
%
%       Jul. 14, 2022 (Hiroyuki Kasai): Fixed algorithm.
%


    % set dimensions and samples
    [m, n] = size(V);

    % set local options
    local_options.norm_h        = 0;
    local_options.norm_w        = 1;
    local_options.lambda        = 0.1;
    local_options.myeps         = 1e-16;
    local_options.metric_type   = 'kl-div';  
    
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
    W = init_factors.W;
    H = init_factors.H;     
      
    % initialize
    method_name = 'Sparse-MU-V';
    epoch = 0;    
    grad_calc_count = 0; 

    if options.verbose > 0
        fprintf('# %s: started ...\n', method_name);           
    end         
    
    % preallocate matrix of ones
    if strcmp(options.metric_type, 'kl-div')    
        Onn = ones(n, n);
        Omn = ones(m, n);
    end
    R_rec = W*H;      
    
    % store initial info
    clear infos;
    [infos, f_val, optgap] = store_nmf_info(V, W, H, [], options, [], epoch, grad_calc_count, 0);
    % store additionally different cost
    sigma = sqrt(1/n * (H.^2*Onn)); 
    reg_val = options.lambda * sum(abs(H(:)./sigma(:)));
    f_val_total = f_val + reg_val;
    infos.cost_reg = reg_val;
    infos.cost_total = f_val_total;      
    
    if options.verbose > 1
        fprintf('%s: Epoch = 0000, cost = %.16e, cost-reg = %.16e, optgap = %.4e\n', method_name, f_val, reg_val, optgap); 
    end  

    % set start time
    start_time = tic();

    % main loop
    while true
        
        % check stop condition
        [stop_flag, reason, max_reached_flag] = check_stop_condition(epoch, infos, options);
        if stop_flag
            display_stop_reason(epoch, infos, options, method_name, reason, max_reached_flag);
            break;
        end         

        % update W
        W = W .* ( ((V./R_rec)*H') ./ max(Omn*H', options.myeps) );
        if options.norm_w ~= 0
            W = normalize_W(W, options.norm_w);
        end
        
        % update reconstruction
        R_rec = max(W*H, options.myeps);
   
        % update H
        denom = W'*Omn + options.lambda*((1/n * H.^2*Onn).^(-1/2));
        H = H .* ( (W'*(V./R_rec) + options.lambda*((H.*(sqrt(n)*H*Onn)) ./ ...
            ((H.^2*Onn).^(3/2)))) ./ ...
                   max(denom, options.myeps) );
        if options.norm_h ~= 0
            H = normalize_H(H, options.norm_h);
        end

        % update sigma
        sigma = sqrt(1/n * (H.^2*Onn)); 
        
        % update reconstruction
        R_rec = max(W*H, options.myeps);        

    
        % measure elapsed time
        elapsed_time = toc(start_time);        
        
        % measure gradient calc count
        grad_calc_count = grad_calc_count + m*n;

        % update epoch
        epoch = epoch + 1;         
        
        % store info
        [infos, f_val] = store_nmf_info(V, W, H, [], options, infos, epoch, grad_calc_count, elapsed_time);  
        % store additionally different cost
        reg_val = options.lambda * sum(abs(H(:)./sigma(:)));
        f_val_total = f_val + reg_val;
        infos.cost_reg = [infos.cost_reg reg_val];
        infos.cost_total = [infos.cost_total f_val_total];        
        
        % display info
        display_info(method_name, epoch, infos, options);    

    end
    
    x.W = W;
    x.H = H;
    
end