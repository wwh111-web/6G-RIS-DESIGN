function  [ris_params]=ris_parameters_v2(varargin)
    freq = varargin{1};
    M = varargin{2};
    N = varargin{3};
    dM = varargin{4};
    dN = varargin{5};
    gM = varargin{6};
    gN = varargin{7};
    gamma = varargin{8};

    ris_params= struct('freq',freq,'M',M,'N',N,'dM',dM,'dN',dN,'gM',gM,'gN',gN,...
                       'gamma',reshape(gamma,1,[]));%response to '0' and '1'
    
    ris_params.pos_center = [0 0 0]';
    ris_params.normal = [1 0 0]';
    ris_params.state = 1;
    ris_params.area = ris_params.dN*ris_params.dM;
    
    dy = ris_params.dM + ris_params.gM;
    dz = ris_params.dN + ris_params.gN;
    
    % RIS lies in Y-Z plane and its broadside is towards +x axis
    pos_ris_ydir = ((0:ris_params.M-1)-(ris_params.M-1)/2)*dy;%ds*wavelength;
    pos_ris_zdir = ((0:ris_params.N-1)-(ris_params.N-1)/2)*dz;%ds*wavelength;
    [pos_y,pos_z]=meshgrid(pos_ris_ydir,pos_ris_zdir);
    ris_params.pos_element = [zeros(ris_params.N*ris_params.M,1) pos_y(:) pos_z(:)]';
    
end