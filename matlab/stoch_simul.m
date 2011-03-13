function info=stoch_simul(var_list)

% Copyright (C) 2001-2011 Dynare Team
%
% This file is part of Dynare.
%
% Dynare is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
%
% Dynare is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with Dynare.  If not, see <http://www.gnu.org/licenses/>.

global M_ options_ oo_ it_

test_for_deep_parameters_calibration(M_);

options_old = options_;
if options_.linear
    options_.order = 1;
end
if options_.order == 1
    options_.replic = 1;
elseif options_.order == 3
    options_.k_order_solver = 1;
end

if isempty(options_.qz_criterium)
    options_.qz_criterium = 1+1e-6;
end

if options_.partial_information == 1 || options_.ACES_solver == 1
    PI_PCL_solver = 1;
    if options_.order ~= 1
        warning('STOCH_SIMUL: forcing order=1 since you are using partial_information or ACES solver')
        options_.order = 1;
    end
else
    PI_PCL_solver = 0;
end

TeX = options_.TeX;

if size(var_list,1) == 0
    var_list = M_.endo_names(1:M_.orig_endo_nbr, :);
end

[i_var,nvar] = varlist_indices(var_list,M_.endo_names);

iter_ = max(options_.periods,1);
if M_.exo_nbr > 0
    oo_.exo_simul= ones(iter_ + M_.maximum_lag + M_.maximum_lead,1) * oo_.exo_steady_state';
end

check_model;

if PI_PCL_solver
    [oo_.dr, info] = PCL_resol(oo_.steady_state,0);
elseif options_.discretionary_policy
    if ~options_.linear
        error(['discretionary_policy solves only linear_quadratic ' ...
               'problems']);
    end
    [oo_.dr,ys,info] = discretionary_policy_1(oo_,options_.instruments);
else
    [oo_.dr, info] = resol(oo_.steady_state,0);
end

if info(1)
    options_ = options_old;
    print_info(info, options_.noprint);
    return
end

if ~options_.noprint
    disp(' ')
    disp('MODEL SUMMARY')
    disp(' ')
    disp(['  Number of variables:         ' int2str(M_.endo_nbr)])
    disp(['  Number of stochastic shocks: ' int2str(M_.exo_nbr)])
    if (options_.block)
        disp(['  Number of state variables:   ' int2str(oo_.dr.npred+oo_.dr.nboth)])
        disp(['  Number of jumpers:           ' int2str(oo_.dr.nfwrd+oo_.dr.nboth)])
    else
        disp(['  Number of state variables:   ' ...
              int2str(length(find(oo_.dr.kstate(:,2) <= M_.maximum_lag+1)))])
        disp(['  Number of jumpers:           ' ...
              int2str(length(find(oo_.dr.kstate(:,2) == M_.maximum_lag+2)))])
    end;
    disp(['  Number of static variables:  ' int2str(oo_.dr.nstatic)])
    my_title='MATRIX OF COVARIANCE OF EXOGENOUS SHOCKS';
    labels = deblank(M_.exo_names);
    headers = char('Variables',labels);
    lh = size(labels,2)+2;
    dyntable(my_title,headers,labels,M_.Sigma_e,lh,10,6);
    if options_.partial_information
        disp(' ')
        disp('SOLUTION UNDER PARTIAL INFORMATION')
        disp(' ')

        if isfield(options_,'varobs')&& ~isempty(options_.varobs)
            PCL_varobs=options_.varobs;
            disp('OBSERVED VARIABLES')
        else
            PCL_varobs=M_.endo_names;
            disp(' VAROBS LIST NOT SPECIFIED')
            disp(' ASSUMED OBSERVED VARIABLES')
        end
        for i=1:size(PCL_varobs,1)
            disp(['    ' PCL_varobs(i,:)])
        end
    end
    disp(' ')
    if options_.order <= 2 && ~PI_PCL_solver
        disp_dr(oo_.dr,options_.order,var_list);
    end
end

if options_.periods > 0 && ~PI_PCL_solver
    if options_.periods <= options_.drop
        disp(['STOCH_SIMUL error: The horizon of simulation is shorter' ...
              ' than the number of observations to be DROPed'])
        options_ =options_old;
        return
    end
    oo_.endo_simul = simult(oo_.dr.ys,oo_.dr);
    dyn2vec;
end

if options_.nomoments == 0
    if PI_PCL_solver
        PCL_Part_info_moments (0, PCL_varobs, oo_.dr, i_var);
    elseif options_.periods == 0
        disp_th_moments(oo_.dr,var_list); 
    else
        disp_moments(oo_.endo_simul,var_list);
    end
end


if options_.irf 
    var_listTeX = M_.endo_names_tex(i_var,:);

    if TeX
        fidTeX = fopen([M_.fname '_IRF.TeX'],'w');
        fprintf(fidTeX,'%% TeX eps-loader file generated by stoch_simul.m (Dynare).\n');
        fprintf(fidTeX,['%% ' datestr(now,0) '\n']);
        fprintf(fidTeX,' \n');
    end
    olditer = iter_;% Est-ce vraiment utile ? Il y a la m�me ligne dans irf... 
    SS(M_.exo_names_orig_ord,M_.exo_names_orig_ord)=M_.Sigma_e+1e-14*eye(M_.exo_nbr);
    cs = transpose(chol(SS));
    tit(M_.exo_names_orig_ord,:) = M_.exo_names;
    if TeX
        titTeX(M_.exo_names_orig_ord,:) = M_.exo_names_tex;
    end
    for i=1:M_.exo_nbr
        if SS(i,i) > 1e-13
            if PI_PCL_solver
                y=PCL_Part_info_irf (0, PCL_varobs, i_var, M_, oo_.dr, options_.irf, i);
            else
                y=irf(oo_.dr,cs(M_.exo_names_orig_ord,i), options_.irf, options_.drop, ...
                      options_.replic, options_.order);
            end
            if options_.relative_irf
                y = 100*y/cs(i,i); 
            end
            irfs   = [];
            mylist = [];
            if TeX
                mylistTeX = [];
            end
            for j = 1:nvar
                assignin('base',[deblank(M_.endo_names(i_var(j),:)) '_' deblank(M_.exo_names(i,:))],...
                         y(i_var(j),:)');
                eval(['oo_.irfs.' deblank(M_.endo_names(i_var(j),:)) '_' ...
                      deblank(M_.exo_names(i,:)) ' = y(i_var(j),:);']); 
                if max(y(i_var(j),:)) - min(y(i_var(j),:)) > 1e-10
                    irfs  = cat(1,irfs,y(i_var(j),:));
                    if isempty(mylist)
                        mylist = deblank(var_list(j,:));
                    else
                        mylist = char(mylist,deblank(var_list(j,:)));
                    end
                    if TeX
                        if isempty(mylistTeX)
                            mylistTeX = deblank(var_listTeX(j,:));
                        else
                            mylistTeX = char(mylistTeX,deblank(var_listTeX(j,:)));
                        end
                    end
                end
            end
            if options_.nograph == 0
                number_of_plots_to_draw = size(irfs,1);
                [nbplt,nr,nc,lr,lc,nstar] = pltorg(number_of_plots_to_draw);
                if nbplt == 0
                elseif nbplt == 1
                    if options_.relative_irf
                        hh = figure('Name',['Relative response to' ...
                                            ' orthogonalized shock to ' tit(i,:)]);
                    else
                        hh = figure('Name',['Orthogonalized shock to' ...
                                            ' ' tit(i,:)]);
                    end
                    for j = 1:number_of_plots_to_draw
                        subplot(nr,nc,j);
                        plot(1:options_.irf,transpose(irfs(j,:)),'-k','linewidth',1);
                        hold on
                        plot([1 options_.irf],[0 0],'-r','linewidth',0.5);
                        hold off
                        xlim([1 options_.irf]);
                        title(deblank(mylist(j,:)),'Interpreter','none');
                    end
                    eval(['print -depsc2 ' M_.fname '_IRF_' deblank(tit(i,:)) '.eps']);
                    if ~exist('OCTAVE_VERSION')
                        eval(['print -dpdf ' M_.fname  '_IRF_' deblank(tit(i,:))]);
                        saveas(hh,[M_.fname  '_IRF_' deblank(tit(i,:)) '.fig']);
                    end
                    if TeX
                        fprintf(fidTeX,'\\begin{figure}[H]\n');
                        for j = 1:number_of_plots_to_draw
                            fprintf(fidTeX,['\\psfrag{%s}[1][][0.5][0]{$%s$}\n'],deblank(mylist(j,:)),deblank(mylistTeX(j,:)));
                        end
                        fprintf(fidTeX,'\\centering \n');
                        fprintf(fidTeX,'\\includegraphics[scale=0.5]{%s_IRF_%s}\n',M_.fname,deblank(tit(i,:)));
                        fprintf(fidTeX,'\\caption{Impulse response functions (orthogonalized shock to $%s$).}',titTeX(i,:));
                        fprintf(fidTeX,'\\label{Fig:IRF:%s}\n',deblank(tit(i,:)));
                        fprintf(fidTeX,'\\end{figure}\n');
                        fprintf(fidTeX,' \n');
                    end
                    %   close(hh)
                else
                    for fig = 1:nbplt-1
                        if options_.relative_irf == 1
                            hh = figure('Name',['Relative response to orthogonalized shock' ...
                                                ' to ' tit(i,:) ' figure ' int2str(fig)]);
                        else
                            hh = figure('Name',['Orthogonalized shock to ' tit(i,:) ...
                                                ' figure ' int2str(fig)]);
                        end
                        for plt = 1:nstar
                            subplot(nr,nc,plt);
                            plot(1:options_.irf,transpose(irfs((fig-1)*nstar+plt,:)),'-k','linewidth',1);
                            hold on
                            plot([1 options_.irf],[0 0],'-r','linewidth',0.5);
                            hold off
                            xlim([1 options_.irf]);
                            title(deblank(mylist((fig-1)*nstar+plt,:)),'Interpreter','none');
                        end
                        eval(['print -depsc2 ' M_.fname '_IRF_' deblank(tit(i,:)) int2str(fig) '.eps']);
                        if ~exist('OCTAVE_VERSION')
                            eval(['print -dpdf ' M_.fname  '_IRF_' deblank(tit(i,:)) int2str(fig)]);
                            saveas(hh,[M_.fname  '_IRF_' deblank(tit(i,:)) int2str(fig) '.fig']);
                        end
                        if TeX
                            fprintf(fidTeX,'\\begin{figure}[H]\n');
                            for j = 1:nstar
                                fprintf(fidTeX,['\\psfrag{%s}[1][][0.5][0]{$%s$}\n'],deblank(mylist((fig-1)*nstar+j,:)),deblank(mylistTeX((fig-1)*nstar+j,:)));
                            end
                            fprintf(fidTeX,'\\centering \n');
                            fprintf(fidTeX,'\\includegraphics[scale=0.5]{%s_IRF_%s%s}\n',M_.fname,deblank(tit(i,:)),int2str(fig));
                            if options_.relative_irf
                                fprintf(fidTeX,['\\caption{Relative impulse response' ...
                                                ' functions (orthogonalized shock to $%s$).}'],deblank(titTeX(i,:)));
                            else
                                fprintf(fidTeX,['\\caption{Impulse response functions' ...
                                                ' (orthogonalized shock to $%s$).}'],deblank(titTeX(i,:)));
                            end
                            fprintf(fidTeX,'\\label{Fig:BayesianIRF:%s:%s}\n',deblank(tit(i,:)),int2str(fig));
                            fprintf(fidTeX,'\\end{figure}\n');
                            fprintf(fidTeX,' \n');
                        end
                        %                                       close(hh);
                    end
                    hh = figure('Name',['Orthogonalized shock to ' tit(i,:) ' figure ' int2str(nbplt) '.']);
                    m = 0; 
                    for plt = 1:number_of_plots_to_draw-(nbplt-1)*nstar;
                        m = m+1;
                        subplot(lr,lc,m);
                        plot(1:options_.irf,transpose(irfs((nbplt-1)*nstar+plt,:)),'-k','linewidth',1);
                        hold on
                        plot([1 options_.irf],[0 0],'-r','linewidth',0.5);
                        hold off
                        xlim([1 options_.irf]);
                        title(deblank(mylist((nbplt-1)*nstar+plt,:)),'Interpreter','none');
                    end
                    eval(['print -depsc2 ' M_.fname '_IRF_' deblank(tit(i,:)) int2str(nbplt) '.eps']);
                    if ~exist('OCTAVE_VERSION')
                        eval(['print -dpdf ' M_.fname  '_IRF_' deblank(tit(i,:)) int2str(nbplt)]);
                        saveas(hh,[M_.fname  '_IRF_' deblank(tit(i,:)) int2str(nbplt) '.fig']);
                    end
                    if TeX
                        fprintf(fidTeX,'\\begin{figure}[H]\n');
                        for j = 1:m
                            fprintf(fidTeX,['\\psfrag{%s}[1][][0.5][0]{$%s$}\n'],deblank(mylist((nbplt-1)*nstar+j,:)),deblank(mylistTeX((nbplt-1)*nstar+j,:)));
                        end
                        fprintf(fidTeX,'\\centering \n');
                        fprintf(fidTeX,'\\includegraphics[scale=0.5]{%s_IRF_%s%s}\n',M_.fname,deblank(tit(i,:)),int2str(nbplt));
                        if options_.relative_irf
                            fprintf(fidTeX,['\\caption{Relative impulse response functions' ...
                                            ' (orthogonalized shock to $%s$).}'],deblank(titTeX(i,:)));
                        else
                            fprintf(fidTeX,['\\caption{Impulse response functions' ...
                                            ' (orthogonalized shock to $%s$).}'],deblank(titTeX(i,:)));
                        end
                        fprintf(fidTeX,'\\label{Fig:IRF:%s:%s}\n',deblank(tit(i,:)),int2str(nbplt));
                        fprintf(fidTeX,'\\end{figure}\n');
                        fprintf(fidTeX,' \n');
                    end
                    %                           close(hh);
                end
            end
        end
        iter_ = olditer;
    end
    if TeX
        fprintf(fidTeX,' \n');
        fprintf(fidTeX,'%% End Of TeX file. \n');
        fclose(fidTeX);
    end
end

if options_.SpectralDensity == 1
    [omega,f] = UnivariateSpectralDensity(oo_.dr,var_list);
end


options_ = options_old;
% temporary fix waiting for local options
options_.partial_information = 0; 