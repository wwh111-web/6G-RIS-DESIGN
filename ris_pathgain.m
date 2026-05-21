function [gain,delay,PL,ph] = ris_pathgain(tx_params,rx_params,ris_params,varargin)
% Path Gain Model of Reconfigurable Intelligent Surface(RIS) for single tx
% and rx antenna 'beamforming(B)' or 'focusing(F)' can specified for the
% Tx-RIS and RIS-Rx segments seperately, so that there are four modes
% combinations, 'BB','BF','FB','FF'. Selecting F or B depends on whether
% the location (F) or direction (B) of tx and rx are known. If mode is not
% specified.'FF' is the default which is the case mimicing the reality.
% 
%  [gain,delay,PL] = ris_pathgain(tx_params,rx_params,ris_params,mode)
% 
% Example:
%     tx_params.Gain = 20;
%     rx_params.Gain = 20;
%     tx_params.pos = [5 -5 0]';
%     rx_params.pos = [5 5 0]';
% %   Use predifined RIS information, state of all elements are set to 0
%     ris_params = ris_parameters('RIS1');
%     [gain,delay,PL] = ris_pathgain(tx_params,rx_params,ris_params);
%     PL
%     ris_params.state = 1;
%     [gain,delay,PL] = ris_pathgain(tx_params,rx_params,ris_params);
%     PL
%     % random coding
%     ris_params.state = randi(2,1,ris_params.N*ris_params.M)-1;
%     [gain,delay,PL] = ris_pathgain(tx_params,rx_params,ris_params);
%     PL
% 
%    % %    Fig.7 in Tang's paper
%     tx_params.Gain = 20;
%     rx_params.Gain = 20;
% %   Use predifined RIS information, state of all elements are set to 0
%     ris_params = ris_parameters('RIS1');
%     ris_params.state = 1;
%     tx_params.pos = [1.3;0;0];
%     rx_d = 2.6;
%     az = -80:80; 
%     for ii = 1:length(az)
%      rx_ang = [deg2rad(az(ii));0];
%       [x,y,z]=sph2cart(rx_ang(1),rx_ang(2),rx_d);
%       rx_params.pos = [x;y;z];
%       [~,~,optimPL(ii)] =ris_pathgain(tx_params,rx_params,ris_params,'FF');
%     end
%     figure;plot(az,-optimPL);


% %    Fig.10(a) in Tang's paper
%     % dual beam coding
%     temp = zeros(ris_params.N,ris_params.M);
%     temp(:,mod(0:ris_params.M-1,14)+1>7)=1;
%     ris_params.state = temp; 
%     rx_d = 2.6;
%     az = -80:80; 
%     for ii = 1:length(az)
%      rx_ang = [deg2rad(az(ii));0];
%       [x,y,z]=sph2cart(rx_ang(1),rx_ang(2),rx_d);
%       rx_params.pos = [x;y;z];
%       [~,~,optimPL(ii)] =ris_pathgain(tx_params,rx_params,ris_params,'FF');
%     end
%     figure;plot(az,-optimPL);
% 
%     tx_params.pos = [5 0 0]';
%     ang = -89:89;PL = zeros(1,length(ang));
%     for aid=1:length(ang)
%         rx_params.pos = [5*cosd(ang(aid)) 5*sind(ang(aid)) 0]';
%         [gain,delay,PL(aid)] = ris_pathgain(tx_params,rx_params,ris_params);
%     end
%     figure;plot(ang,-PL)
%     % adaptive beamforming
%     ris_params.state = 'adaptive'; 
%     tx_params.pos = [1 0 0]';
%     ang = -89:89;PL = zeros(1,length(ang));
%     for aid=1:length(ang)
%         rx_params.pos = [1*cosd(ang(aid)) 1*sind(ang(aid)) 0]';
%         [gain,delay,PL(aid)] = ris_pathgain(tx_params,rx_params,ris_params);
%     end
%     figure;plot(ang,-PL)

Gt = db2pow(tx_params.Gain);
pos_tx = tx_params.pos;
Gr =  db2pow(rx_params.Gain);
pos_rx = rx_params.pos;

% if isempty(ris_params) 
%     type = 'RIS1';
%     [ris_params]=ris_parameters(type);
% elseif ischar(ris_params)
%     type = ris_params;
%     [ris_params]=ris_parameters(type,varargin);
% end

% T mode, R mode 'BB','BF','FB','FF'
% 'F' - approach the reality whether in near field or far field
% 'B' -far field assumption(approximation)
mode = [1 1];
if nargin>3 && ischar(varargin{1}) && length(varargin{1})==2
    switch upper(varargin{1}) 
        case 'BB' % 
            mode = [0 0];
        case 'BF'
            mode = [0 1];
        case 'FB'
            mode = [1 0];
        case 'FF'
            mode = [1 1];
        otherwise
            mode = [1 1];
    end
end

freq = ris_params.freq;
cspeed = physconst('lightspeed');
wavelength = cspeed/freq;

N = ris_params.N;
M = ris_params.M;
NM = N*M;
%ds = ris_params.ds;
dN = ris_params.dN;%m
dM = ris_params.dM;%m
pos_center_ris = ris_params.pos_center;
norm_ris = ris_params.normal;

gamma = ris_params.gamma(:);
pos_ris  = ris_params.pos_element;

%  [1 0 0]---> norm of ris
% if any(norm_ris(:)~=[1;0;0])
%     [az,el] = cart2sph(norm_ris(1),norm_ris(2),norm_ris(3));
%     R = azelaxes(rad2deg(az),rad2deg(el));
% else
%     R = 1;
% end
% pos_ris = pos_center_ris + R*pos_ris;

if mode(1)
    pos_ris_1 = pos_center_ris + pos_ris;
else
    pos_ris_1 = pos_center_ris;    
end
if mode(2)
    pos_ris_2 = pos_center_ris + pos_ris;
else
    pos_ris_2 = pos_center_ris;    
end

vec_tx2ris = pos_center_ris - pos_tx;
d_tx_ris = norm(vec_tx2ris);
vec_ris2rx = pos_rx - pos_center_ris;
d_ris_rx = norm(vec_ris2rx);

state = ris_params.state(:);%1

if isscalar(state)
    state = state*ones(NM,1);
elseif length(state)~=NM
    error('no. of state is not equal to no. of RIS element');
end

% gain = zeros(1,NM);
% delay = zeros(1,NM);
% for nm = 1:NM
%     vec_nm_tx_ris = pos_ris(:,nm) - pos_tx;
%     vec_nm_ris_rx = pos_rx-pos_ris(:,nm);
% 
%     d_nm_tx_ris = norm(vec_nm_tx_ris); %distance between tx antenna and (n,m)-th RIS element
%     d_nm_ris_rx = norm(vec_nm_ris_rx); %distance between (n,m)-th RIS element and rx antenna
% 
% %     theta_nm_in = acos(-vec_nm_tx_ris'*norm_ris/d_nm_tx_ris);
% %     theta_nm_out = acos(vec_nm_ris_rx'*norm_ris/d_nm_ris_rx);
% %     theta_tx_nm = acos(vec_nm_tx_ris'*vec_tx2ris/(d_tx_ris*d_nm_tx_ris));
% %     theta_rx_nm = acos(vec_nm_ris_rx'*vec_ris2rx/(d_ris_rx*d_nm_ris_rx));
% %     Ftx = cos(theta_tx_nm)^(Gt/2-1); %Normalized power radiation pattern of the transmit antenna
% %     Frx = cos(theta_rx_nm)^(Gr/2-1); %Normalized power radiation pattern of the receive antenna
% %     Fcombine = Ftx*Frx*cos(theta_nm_in)*cos(theta_nm_out);
% 
%     cos_theta_nm_in = -vec_nm_tx_ris'*norm_ris/d_nm_tx_ris;
%     cos_theta_nm_out = vec_nm_ris_rx'*norm_ris/d_nm_ris_rx;
%     cos_theta_tx_nm = vec_nm_tx_ris'*vec_tx2ris/(d_tx_ris*d_nm_tx_ris);
%     cos_theta_rx_nm = vec_nm_ris_rx'*vec_ris2rx/(d_ris_rx*d_nm_ris_rx);
%     Ftx = cos_theta_tx_nm^(Gt/2-1); %Normalized power radiation pattern of the transmit antenna
%     Frx = cos_theta_rx_nm^(Gr/2-1); %Normalized power radiation pattern of the receive antenna
%     Fcombine = Ftx*Frx*cos_theta_nm_in*cos_theta_nm_out;
%     
% %     if adaptive
% %          temp = mod((d_nm_tx_ris+d_nm_ris_rx)/wavelength,1);
% %          [~,temp]=min(abs(temp-radian));
% %          state(nm) = temp;
% %     end
%     gain(nm) = sqrt(Gt*Gr)*dN*dM*sqrt(Fcombine)*gamma(state(nm))/(4*pi*d_nm_tx_ris*d_nm_ris_rx)*...
%            exp(-1j*2*pi/wavelength*(d_nm_tx_ris+d_nm_ris_rx));
%     delay(nm) = (d_nm_tx_ris+d_nm_ris_rx)/cspeed;
% 
% end

% replace for over cell ops with vector calculation
    vec_nm_tx_ris = pos_ris_1 - pos_tx;
    vec_nm_ris_rx = pos_rx - pos_ris_2;

    d_nm_tx_ris = sqrt(sum(abs(vec_nm_tx_ris).^2)'); %distance between tx antenna and (n,m)-th RIS element
    d_nm_ris_rx = sqrt(sum(abs(vec_nm_ris_rx).^2)'); %distance between (n,m)-th RIS element and rx antenna

    %For beamforming,it is the phase for the center of RIS, for focusing,
    %they are the phase for all RIS element.
    phase1 = exp(-1j*2*pi/wavelength*d_nm_tx_ris); 
    phase2 = exp(-1j*2*pi/wavelength*d_nm_ris_rx); %
    
    % For beamforming, extra phase shift due to RIS array geometry.
    if ~mode(1) %beamforming
        phase1 =  phase1*exp(-1j*2*pi/wavelength*pos_ris'*vec_nm_tx_ris/d_nm_tx_ris);
    end
    if ~mode(2) %beamforming
        phase2 =  phase2*exp(1j*2*pi/wavelength*pos_ris'*vec_nm_ris_rx/d_nm_ris_rx);
    end
    
    cos_theta_nm_in = -vec_nm_tx_ris'*norm_ris./d_nm_tx_ris;
    cos_theta_nm_out = vec_nm_ris_rx'*norm_ris./d_nm_ris_rx;
    Ftx = 1;Frx = 1;
    if Gt>2 
        if isfield(tx_params,'norm_tx')
            norm_tx = tx_params.normal;
        else
            norm_tx = vec_tx2ris./d_tx_ris;
        end
        %theta_tx_nm = acos(vec_nm_tx_ris'*norm_tx/d_nm_tx_ris);
        %Ftx = cos(theta_tx_nm)^(Gt/2-1); %Normalized power radiation pattern of the transmit antenna
        %cos_theta_tx_nm = vec_nm_tx_ris'*vec_tx2ris./(d_tx_ris*d_nm_tx_ris);
        if mode(1) %valid for 'focus'
            cos_theta_tx_nm = (vec_nm_tx_ris'*norm_tx./d_nm_tx_ris);
        else % for 'beamforming', don't discrminate cell unit
            cos_theta_tx_nm = (vec_tx2ris'*norm_tx./d_tx_ris);
        end
        Ftx = cos_theta_tx_nm.^(Gt/2-1);
    end
    if Gr>2 
        if isfield(tx_params,'norm_rx')
            norm_rx = rx_params.normal;
        else
            norm_rx = -vec_ris2rx./d_ris_rx;
        end
        %theta_rx_nm = acos(-vec_nm_ris_rx'*norm_rx/d_nm_ris_rx);
        %Frx = cos(theta_rx_nm)^(Gr/2-1); %Normalized power radiation pattern of the receive antenna
        %cos_theta_rx_nm = vec_nm_ris_rx'*vec_ris2rx./(d_ris_rx*d_nm_ris_rx);
        if mode(2) %valid for 'focus'
            cos_theta_rx_nm = (-vec_nm_ris_rx'*norm_rx./d_nm_ris_rx);
        else
            cos_theta_rx_nm = (-vec_ris2rx'*norm_rx./d_ris_rx);
        end
        Frx = cos_theta_rx_nm.^(Gr/2-1);
    end
    
    % Tang's model
    Fcombine = Ftx.*Frx.*cos_theta_nm_in.*cos_theta_nm_out;
    % Emil's model
    % Fcombine = Ftx.*Frx.*cos_theta_nm_in.^2;
    
    gain = sqrt(Gt*Gr)*dN*dM*sqrt(Fcombine).*gamma(state)./(4*pi*d_nm_tx_ris.*d_nm_ris_rx) ...
           .*phase1.*phase2;
    delay = (d_nm_tx_ris+d_nm_ris_rx)/cspeed;
    ph.stage1 = phase1;
    ph.stage2 = phase2;
    
    PL = 1./abs(sum(gain))^2;
    PL = pow2db(PL);

end


