function disp_moments(y,var_list)

% Copyright (C) 2001-2008 Dynare Team
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

  global M_ options_ oo_
  
  warning_old_state = warning;
  warning off
  nvar = size(var_list,1);
  if nvar == 0
    nvar = M_.endo_nbr;
    ivar = [1:nvar]';
  else
    ivar=zeros(nvar,1);
    for i=1:nvar
      i_tmp = strmatch(var_list(i,:),M_.endo_names,'exact');
      if isempty(i_tmp)
      	error (['One of the variable specified does not exist']) ;
      else
	ivar(i) = i_tmp;
      end
    end
  end
  y = y(ivar,options_.drop+M_.maximum_lag+1:end)';
  
  m = mean(y);
  y = y - repmat(m,size(y,1),1);
  s2 = mean(y.*y);
  s = sqrt(s2);
  oo_.mean = m;
  oo_.var = y'*y/size(y,1);

  labels = deblank(M_.endo_names(ivar,:));
  
  if options_.nomoments == 0
    z = [ m' s' s2' (mean(y.^3)./s2.^1.5)' (mean(y.^4)./(s2.*s2)-3)' ];
  
    title='MOMENTS OF SIMULATED VARIABLES';
    if options_.hp_filter
      title = [title ' (HP filter, lambda = ' ...
	       int2str(options_.hp_filter) ')'];
    end
    headers=strvcat('VARIABLE','MEAN','STD. DEV.','VARIANCE','SKEWNESS', ...
		    'KURTOSIS');
    table(title,headers,labels,z,size(labels,2)+2,16,6);
  end
  
  if options_.nocorr == 0
    corr = (y'*y/size(y,1))./(s'*s);
    title = 'CORRELATION OF SIMULATED VARIABLES';
    if options_.hp_filter
      title = [title ' (HP filter, lambda = ' ...
	       int2str(options_.hp_filter) ')'];
    end
    headers = strvcat('VARIABLE',M_.endo_names(ivar,:));
    table(title,headers,labels,corr,size(labels,2)+2,8,4);
  end
  
  ar = options_.ar;
  options_ = set_default_option(options_,'ar',5);
  ar = options_.ar;
  if ar > 0
    autocorr = [];
    for i=1:ar
      oo_.autocorr{i} = y(ar+1:end,:)'*y(ar+1-i:end-i,:)./((size(y,1)-ar)*s'*s);
      autocorr = [ autocorr diag(oo_.autocorr{i}) ];
    end
    title = 'AUTOCORRELATION OF SIMULATED VARIABLES';
    if options_.hp_filter
      title = [title ' (HP filter, lambda = ' ...
	       int2str(options_.hp_filter) ')'];
    end
    headers = strvcat('VARIABLE',int2str([1:ar]'));
    table(title,headers,labels,autocorr,size(labels,2)+2,8,4);
  end
  
  warning(warning_old_state);
% 10/03/02 MJ corrected order std. dev var in printed report.
% 01/02/03 MJ added correlation and autocorrelation
% 01/19/03 MJ corrected variable name truncation
% 02/18/03 MJ added subtitle for HP filter
% 03/02/03 MJ added M_.maximum_lag to the number of entries of y
% 04/28/03 MJ modified handling of options_
% 06/23/03 MJ added warning off
