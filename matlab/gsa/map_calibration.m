function map_calibration(OutputDirectoryName, Model, DynareOptions, DynareResults, EstimatedParameters, BayesInfo)

% Copyright (C) 2014 Dynare Team
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

fname_ = Model.fname;
pnames = Model.param_names(EstimatedParameters.param_vals(:,1),:);
pvalue_ks = DynareOptions.opt_gsa.pvalue_ks;
indx_irf = [];
indx_moment = [];
DynareOptions.nodisplay = 1;
init = ~DynareOptions.opt_gsa.load_stab;

options_mcf.pvalue_ks = DynareOptions.opt_gsa.pvalue_ks;
options_mcf.pvalue_corr = DynareOptions.opt_gsa.pvalue_corr;
options_mcf.alpha2 = DynareOptions.opt_gsa.alpha2_stab;
options_mcf.param_names = pnames;
options_mcf.fname_ = fname_;
options_mcf.OutputDirectoryName = OutputDirectoryName;

skipline()
disp('Sensitivity analysis for calibration criteria')

if DynareOptions.opt_gsa.ppost,
    filetoload=dir([Model.dname filesep 'metropolis' filesep fname_ '_param_irf*.mat']);
    lpmat=[];
    for j=1:length(filetoload),
        load([Model.dname filesep 'metropolis' filesep fname_ '_param_irf',int2str(j),'.mat'])
        lpmat = [lpmat; stock];
        clear stock
    end
    type = 'post';
else
    if DynareOptions.opt_gsa.pprior
        filetoload=[OutputDirectoryName '/' fname_ '_prior'];
        load(filetoload,'lpmat','lpmat0','istable','iunstable','iindeterm','iwrong' ,'infox')
        lpmat = [lpmat0 lpmat];
        type = 'prior';
    else
        filetoload=[OutputDirectoryName '/' fname_ '_mc'];
        load(filetoload,'lpmat','lpmat0','istable','iunstable','iindeterm','iwrong' ,'infox')
        lpmat = [lpmat0 lpmat];
        type = 'mc';
    end        
end
[Nsam, np] = size(lpmat);
npar = size(pnames,1);
nshock = np - npar;

nbr_irf_restrictions = size(DynareOptions.endogenous_prior_restrictions.irf,1);
nbr_moment_restrictions = size(DynareOptions.endogenous_prior_restrictions.moment,1);

if init
mat_irf=cell(nbr_irf_restrictions,1);
for ij=1:nbr_irf_restrictions,
    mat_irf{ij}=NaN(Nsam,length(DynareOptions.endogenous_prior_restrictions.irf{ij,3}));
end

mat_moment=cell(nbr_moment_restrictions,1);
for ij=1:nbr_moment_restrictions,
    mat_moment{ij}=NaN(Nsam,length(DynareOptions.endogenous_prior_restrictions.moment{ij,3}));
end

irestrictions = [1:Nsam];
h = dyn_waitbar(0,'Please wait...');
for j=1:Nsam,
    Model = set_all_parameters(lpmat(j,:)',EstimatedParameters,Model);
    [Tt,Rr,SteadyState,info] = dynare_resolve(Model,DynareOptions,DynareResults,'restrict');
    if info(1)==0,
        [info, info_irf, info_moment, data_irf, data_moment]=endogenous_prior_restrictions(Tt,Rr,Model,DynareOptions,DynareResults);
        if ~isempty(info_irf)
            for ij=1:nbr_irf_restrictions,
                mat_irf{ij}(j,:)=data_irf{ij}(:,2)';
            end
            indx_irf(j,:)=info_irf(:,1);
        end
        if ~isempty(info_moment)
            for ij=1:nbr_moment_restrictions,
                mat_moment{ij}(j,:)=data_moment{ij}(:,2)';
            end
            indx_moment(j,:)=info_moment(:,1);
        end
    else
        irestrictions(j)=0;
    end
    dyn_waitbar(j/Nsam,h,['MC iteration ',int2str(j),'/',int2str(Nsam)])
end
dyn_waitbar_close(h);

irestrictions=irestrictions(find(irestrictions));
xmat=lpmat(irestrictions,:);
skipline()
endo_prior_restrictions=DynareOptions.endogenous_prior_restrictions;
save([OutputDirectoryName,filesep,fname_,'_',type,'_restrictions'],'xmat','mat_irf','mat_moment','irestrictions','indx_irf','indx_moment','endo_prior_restrictions');
else
load([OutputDirectoryName,filesep,fname_,'_',type,'_restrictions'],'xmat','mat_irf','mat_moment','irestrictions','indx_irf','indx_moment','endo_prior_restrictions');
end    
if ~isempty(indx_irf),
    
    % For single legend search which has maximum nbr of restrictions 
    all_irf_couples = cellstr([char(endo_prior_restrictions.irf(:,1)) char(endo_prior_restrictions.irf(:,2))]);
    irf_couples = unique(all_irf_couples);
    nbr_irf_couples = size(irf_couples,1);
    plot_indx = NaN(nbr_irf_couples,1);
    time_matrix=cell(nbr_irf_couples,1);
    irf_matrix=cell(nbr_irf_couples,1);
    irf_mean=cell(nbr_irf_couples,1);
    irf_median=cell(nbr_irf_couples,1);
    irf_var=cell(nbr_irf_couples,1);
    irf_HPD=cell(nbr_irf_couples,1);
    irf_distrib=cell(nbr_irf_couples,1);
    maxijv=0;
    for ij=1:nbr_irf_restrictions
        if length(endo_prior_restrictions.irf{ij,3})>maxijv
            maxij=ij;maxijv=length(endo_prior_restrictions.irf{ij,3});
        end
        plot_indx(ij) = find(strcmp(irf_couples,all_irf_couples(ij,:)));
        time_matrix{plot_indx(ij)} = [time_matrix{plot_indx(ij)} endo_prior_restrictions.irf{ij,3}];
    end
    
    indx_irf = indx_irf(irestrictions,:);
    h1=dyn_figure(DynareOptions,'name',[type ' evaluation of irf restrictions']);
    nrow=ceil(sqrt(nbr_irf_couples));
    ncol=nrow;
    if nrow*(nrow-1)>nbr_irf_couples,
        ncol=nrow-1;
    end
    for ij=1:nbr_irf_restrictions,
        mat_irf{ij}=mat_irf{ij}(irestrictions,:);
        irf_matrix{plot_indx(ij)} = [irf_matrix{plot_indx(ij)} mat_irf{ij}];
        for ik=1:size(mat_irf{ij},2),
            [Mean,Median,Var,HPD,Distrib] = ...
                posterior_moments(mat_irf{ij}(:,ik),0,DynareOptions.mh_conf_sig);
            irf_mean{plot_indx(ij)} = [irf_mean{plot_indx(ij)}; Mean];
            irf_median{plot_indx(ij)} = [irf_median{plot_indx(ij)}; Median];
            irf_var{plot_indx(ij)} = [irf_var{plot_indx(ij)}; Var];
            irf_HPD{plot_indx(ij)} = [irf_HPD{plot_indx(ij)}; HPD];
            irf_distrib{plot_indx(ij)} = [irf_distrib{plot_indx(ij)}; Distrib'];
        end
        leg = num2str(endo_prior_restrictions.irf{ij,3}(1));
        aleg = num2str(endo_prior_restrictions.irf{ij,3}(1));
        if size(mat_irf{ij},2)>1,
            leg = [leg,':' ,num2str(endo_prior_restrictions.irf{ij,3}(end))];
            aleg = [aleg,'-' ,num2str(endo_prior_restrictions.irf{ij,3}(end))];
        end        
        if length(time_matrix{plot_indx(ij)})==1,
            figure(h1),
            subplot(nrow,ncol, plot_indx(ij)),
            hc = cumplot(mat_irf{ij}(:,ik));
            set(hc,'color','k','linewidth',2)
            hold all,
            a=axis;
            x1val=max(endo_prior_restrictions.irf{ij,4}(1),a(1));
            x2val=min(endo_prior_restrictions.irf{ij,4}(2),a(2));
            hp = patch([x1val x2val x2val x1val],a([3 3 4 4]),'b');
            set(hp,'FaceAlpha', 0.5)
            hold off,
            %         hold off,
            title([endo_prior_restrictions.irf{ij,1},' vs ',endo_prior_restrictions.irf{ij,2}, '(', leg,')'],'interpreter','none'),
            %set(legend_h,'Xlim',[0 1]);
            %         if ij==maxij
            %             leg1 = num2str(endo_prior_restrictions.irf{ij,3}(:));
            %             [legend_h,object_h,plot_h,text_strings]=legend(leg1);
            %             Position=get(legend_h,'Position');Position(1:2)=[-0.055 0.95-Position(4)];
            %             set(legend_h,'Position',Position);
            %         end
        end
        % hc = get(h,'Children');
        %for i=2:2:length(hc)
        %end
        indx1 = find(indx_irf(:,ij)==0);
        indx2 = find(indx_irf(:,ij)~=0);
        atitle0=[endo_prior_restrictions.irf{ij,1},' vs ',endo_prior_restrictions.irf{ij,2}, '(', leg,')'];
        fprintf(['%4.1f%% of the prior support matches IRF ',atitle0,' inside [%4.1f, %4.1f]\n'],length(indx1)/length(irestrictions)*100,endo_prior_restrictions.irf{ij,4})
        % aname=[type '_irf_calib_',int2str(ij)];
        aname=[type '_irf_calib_',endo_prior_restrictions.irf{ij,1},'_vs_',endo_prior_restrictions.irf{ij,2},'_',aleg];
        atitle=[type ' IRF Calib: Parameter(s) driving ',endo_prior_restrictions.irf{ij,1},' vs ',endo_prior_restrictions.irf{ij,2}, '(', leg,')'];
        options_mcf.amcf_name = aname;
        options_mcf.amcf_title = atitle;
        options_mcf.beha_title = 'IRF prior restriction';
        options_mcf.nobeha_title = 'NO IRF prior restriction';
        options_mcf.title = atitle0;
        if ~isempty(indx1) && ~isempty(indx2)
            mcf_analysis(xmat(:,nshock+1:end), indx1, indx2, options_mcf, DynareOptions);
        end

%         [proba, dproba] = stab_map_1(xmat, indx1, indx2, aname, 0);
%         indplot=find(proba<pvalue_ks);
%         if ~isempty(indplot)
%             stab_map_1(xmat, indx1, indx2, aname, 1, indplot, OutputDirectoryName,[],atitle);
%         end
    end
    figure(h1);
    for ij=1:nbr_irf_couples,
        if length(time_matrix{ij})>1,
            subplot(nrow,ncol, ij)
            itmp = (find(plot_indx==ij));
            plot(time_matrix{ij},[max(irf_matrix{ij})' min(irf_matrix{ij})'],'k--','linewidth',2)
            hold on,
            plot(time_matrix{ij},irf_median{ij},'k','linewidth',2)
            plot(time_matrix{ij},[irf_distrib{ij}],'k-')
            a=axis;
            tmp=[];
            for ir=1:length(itmp),
                for it=1:length(endo_prior_restrictions.irf{itmp(ir),3})
                temp_index = find(time_matrix{ij}==endo_prior_restrictions.irf{itmp(ir),3}(it));
                tmp(temp_index,:) = endo_prior_restrictions.irf{itmp(ir),4};
                end
            end
%             tmp = cell2mat(endo_prior_restrictions.irf(itmp,4));
            tmp(isinf(tmp(:,1)),1)=a(3);
            tmp(isinf(tmp(:,2)),2)=a(4);
            hp = patch([time_matrix{ij} time_matrix{ij}(end:-1:1)],tmp(:),'b');
            set(hp,'FaceAlpha',[0.5])
            plot(a(1:2),[0 0],'r')
            hold off,
            axis([max(1,a(1)) a(2:4)])
            box on,
            set(gca,'xtick',sort(time_matrix{ij}))
            itmp = min(itmp);
            title([endo_prior_restrictions.irf{itmp,1},' vs ',endo_prior_restrictions.irf{itmp,2}],'interpreter','none'),
        end
    end
    dyn_saveas(h1,[OutputDirectoryName,filesep,fname_,'_',type,'_irf_restrictions'],DynareOptions);

    skipline()
end

if ~isempty(indx_moment)
    options_mcf.param_names = char(BayesInfo.name);
    all_moment_couples = cellstr([char(endo_prior_restrictions.moment(:,1)) char(endo_prior_restrictions.moment(:,2))]);
    moment_couples = unique(all_moment_couples);
    nbr_moment_couples = size(moment_couples,1);
    plot_indx = NaN(nbr_moment_couples,1);
    time_matrix=cell(nbr_moment_couples,1);
    moment_matrix=cell(nbr_moment_couples,1);
    moment_mean=cell(nbr_moment_couples,1);
    moment_median=cell(nbr_moment_couples,1);
    moment_var=cell(nbr_moment_couples,1);
    moment_HPD=cell(nbr_moment_couples,1);
    moment_distrib=cell(nbr_moment_couples,1);
    % For single legend search which has maximum nbr of restrictions 
    maxijv=0;
    for ij=1:nbr_moment_restrictions
        if length(endo_prior_restrictions.moment{ij,3})>maxijv
            maxij=ij;maxijv=length(endo_prior_restrictions.moment{ij,3});
        end
        plot_indx(ij) = find(strcmp(moment_couples,all_moment_couples(ij,:)));
        time_matrix{plot_indx(ij)} = [time_matrix{plot_indx(ij)} endo_prior_restrictions.moment{ij,3}];
    end
    
    indx_moment = indx_moment(irestrictions,:);
    h2=dyn_figure(DynareOptions,'name',[type ' evaluation of moment restrictions']);
    nrow=ceil(sqrt(nbr_moment_couples));
    ncol=nrow;
    if nrow*(nrow-1)>nbr_moment_couples,
        ncol=nrow-1;
    end
    
    for ij=1:nbr_moment_restrictions,
        mat_moment{ij}=mat_moment{ij}(irestrictions,:);
        moment_matrix{plot_indx(ij)} = [moment_matrix{plot_indx(ij)} mat_moment{ij}];
        for ik=1:size(mat_moment{ij},2),
            [Mean,Median,Var,HPD,Distrib] = ...
                posterior_moments(mat_moment{ij}(:,ik),0,DynareOptions.mh_conf_sig);
            moment_mean{plot_indx(ij)} = [moment_mean{plot_indx(ij)}; Mean];
            moment_median{plot_indx(ij)} = [moment_median{plot_indx(ij)}; Median];
            moment_var{plot_indx(ij)} = [moment_var{plot_indx(ij)}; Var];
            moment_HPD{plot_indx(ij)} = [moment_HPD{plot_indx(ij)}; HPD];
            moment_distrib{plot_indx(ij)} = [moment_distrib{plot_indx(ij)}; Distrib'];
        end
        leg = num2str(endo_prior_restrictions.moment{ij,3}(1));
        aleg = num2str(endo_prior_restrictions.moment{ij,3}(1));
        if size(mat_moment{ij},2)>1,
            leg = [leg,':' ,num2str(endo_prior_restrictions.moment{ij,3}(end))];
            aleg = [aleg,'_' ,num2str(endo_prior_restrictions.moment{ij,3}(end))];
        end
        if length(time_matrix{plot_indx(ij)})==1,
            figure(h2),
            subplot(nrow,ncol,plot_indx(ij)),
            hc = cumplot(mat_moment{ij}(:,ik));
            set(hc,'color','k','linewidth',2)
            hold all,
            %     hist(mat_moment{ij}),
            a=axis;
            x1val=max(endo_prior_restrictions.moment{ij,4}(1),a(1));
            x2val=min(endo_prior_restrictions.moment{ij,4}(2),a(2));
            hp = patch([x1val x2val x2val x1val],a([3 3 4 4]),'b');
            set(hp,'FaceAlpha', 0.5)
            hold off,
            title([endo_prior_restrictions.moment{ij,1},' vs ',endo_prior_restrictions.moment{ij,2},'(',leg,')'],'interpreter','none'),
%         if ij==maxij
%             leg1 = num2str(endo_prior_restrictions.moment{ij,3}(:));
%             [legend_h,object_h,plot_h,text_strings]=legend(leg1);
%             Position=get(legend_h,'Position');Position(1:2)=[-0.055 0.95-Position(4)];
%             set(legend_h,'Position',Position);
%         end
        end
        indx1 = find(indx_moment(:,ij)==0);
        indx2 = find(indx_moment(:,ij)~=0);
        atitle0=[endo_prior_restrictions.moment{ij,1},' vs ',endo_prior_restrictions.moment{ij,2}, '(', leg,')'];
        fprintf(['%4.1f%% of the prior support matches MOMENT ',atitle0,' inside [%4.1f, %4.1f]\n'],length(indx1)/length(irestrictions)*100,endo_prior_restrictions.moment{ij,4})
        % aname=[type '_moment_calib_',int2str(ij)];
        aname=[type '_moment_calib_',endo_prior_restrictions.moment{ij,1},'_vs_',endo_prior_restrictions.moment{ij,2},'_',aleg];
        atitle=[type ' MOMENT Calib: Parameter(s) driving ',endo_prior_restrictions.moment{ij,1},' vs ',endo_prior_restrictions.moment{ij,2}, '(', leg,')'];
        options_mcf.amcf_name = aname;
        options_mcf.amcf_title = atitle;
        options_mcf.beha_title = 'moment prior restriction';
        options_mcf.nobeha_title = 'NO moment prior restriction';
        options_mcf.title = atitle0;
        if ~isempty(indx1) && ~isempty(indx2)
            mcf_analysis(xmat, indx1, indx2, options_mcf, DynareOptions);
        end
        
%         [proba, dproba] = stab_map_1(xmat, indx1, indx2, aname, 0);
%         indplot=find(proba<pvalue_ks);
%         if ~isempty(indplot)
%             stab_map_1(xmat, indx1, indx2, aname, 1, indplot, OutputDirectoryName,[],atitle);
%         end
    end
    figure(h2);
    for ij=1:nbr_moment_couples,
        if length(time_matrix{ij})>1,
            subplot(nrow,ncol, ij)
            itmp = (find(plot_indx==ij));
            plot(time_matrix{ij},[max(moment_matrix{ij})' min(moment_matrix{ij})'],'k--','linewidth',2)
            hold on,
            plot(time_matrix{ij},moment_median{ij},'k','linewidth',2)
            plot(time_matrix{ij},[moment_distrib{ij}],'k-')
            a=axis;
            tmp=[];
            for ir=1:length(itmp),
                for it=1:length(endo_prior_restrictions.moment{itmp(ir),3})
                temp_index = find(time_matrix{ij}==endo_prior_restrictions.moment{itmp(ir),3}(it));
                tmp(temp_index,:) = endo_prior_restrictions.moment{itmp(ir),4};
                end
            end
%             tmp = cell2mat(endo_prior_restrictions.moment(itmp,4));
            tmp(isinf(tmp(:,1)),1)=a(3);
            tmp(isinf(tmp(:,2)),2)=a(4);
            hp = patch([time_matrix{ij} time_matrix{ij}(end:-1:1)],tmp(:),'b');
            set(hp,'FaceAlpha',[0.5])
            plot(a(1:2),[0 0],'r')
            hold off,
            axis(a)
            box on,
            set(gca,'xtick',sort(time_matrix{ij}))
            itmp = min(itmp);
            title([endo_prior_restrictions.moment{itmp,1},' vs ',endo_prior_restrictions.moment{itmp,2}],'interpreter','none'),
        end
    end
    dyn_saveas(h2,[OutputDirectoryName,filesep,fname_,'_',type,'_moment_restrictions'],DynareOptions);
    skipline()
end
return

