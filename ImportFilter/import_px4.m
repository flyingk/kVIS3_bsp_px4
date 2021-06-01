% kVIS3 Data Visualisation
%
% Copyright (C) 2012 - present  Kai Lehmkuehler, Matt Anderson and
% contributors
%
% Contact: kvis3@uav-flightresearch.com
%
% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with this program.  If not, see <http://www.gnu.org/licenses/>.

function fds = import_px4(file)

if ~nargin
    file = 'log_28_2021-4-2-16-38-26.ulg';  % Small (0.5 MB)
%     file = 'log_13_2019-9-14-02-08-36.ulg'; % Medium (7 MB)
%     file = 'log_0_2019-9-13-16-25-54.ulg';  % Large (25 MB)

end

tic

fprintf('Importing PX4 .ulg file\n');
fprintf('\t%s\n\n',file);

%% get new fds structure
fds = kVIS_fdsInitNew();

fds.BoardSupportPackage = 'PX4';

[fds, parentNode] = kVIS_fdsAddTreeBranch(fds, 0, 'PX4_data');

%% Convert ulg file into struct to read
ulg = ulgReader(file);
% ulg = ulgReader_csv(file); % old way of doing things, might be needed in the future

t_start = inf;
t_end = -inf;

%% Convert into something kVIS can use
logs = fieldnames(ulg.logs);

% Loop through each group name
for ii = 1:numel(logs)
    
    % Extract log name
    groupName = logs{ii};
    fprintf('\tImporting field %s\n',groupName);
    
    % Get the variable names/units/frames
    varNames = fieldnames(ulg.logs.(groupName)); ...
        n_channels = numel(varNames); ...
        n_samples = numel(ulg.logs.(groupName).(varNames{1}));
    varUnits = repmat({'N/A'}, n_channels,1);
    varFrames = repmat({'Unknown Frame'}, n_channels,1);
        
    % Get the data
    data = nan(n_samples,n_channels);
    for jj = 1:n_channels
        data(:,jj) = ulg.logs.(groupName).(varNames{jj});
    end
    
    % Fix the time element
    varNames{1} = 'Time';
    varUnits{1} = 's';
    varFrames{1} = '';
    data(:,1) = data(:,1) / 1e6;
    
    % Find t_start and t_end
    t_start = min(t_start,data(1,1));
    t_end   = max(t_end  ,data(end,1));
    

    % Add special fields that PX4 doesn't normally have (because it's stupid)
    if contains(groupName,'vehicle_attitude_setpoint')
        % Add extra stuff to the labelling
        varNames  = [varNames; {'roll_d'};{'pitch_d'};{'yaw_d' }];
        varUnits  = [varUnits; {'deg' };{'deg'  };{'deg' }];
        varFrames = [varFrames;{'body'};{'body' };{'body'}];
        
        % Find which variables to use
        q0c = data(:,strcmp(varNames,'q_d_0'));
        q1c = data(:,strcmp(varNames,'q_d_1'));
        q2c = data(:,strcmp(varNames,'q_d_2'));
        q3c = data(:,strcmp(varNames,'q_d_3'));
        
        % Convert quaternions to euler angles and store
        quat_angles = [q0c, q1c, q2c, q3c];
        euler_angles = q2e(quat_angles)*180.0/pi;
        data = [ data, euler_angles ];
        
    elseif contains(groupName,'vehicle_attitude')
        % Add extra stuff to the labelling
        varNames  = [varNames; {'roll'};{'pitch'};{'yaw' }];
        varUnits  = [varUnits; {'deg' };{'deg'  };{'deg' }];
        varFrames = [varFrames;{'body'};{'body' };{'body'}];
        
        % Find which variables to use
        q0 = data(:,strcmp(varNames,'q_0'));
        q1 = data(:,strcmp(varNames,'q_1'));
        q2 = data(:,strcmp(varNames,'q_2'));
        q3 = data(:,strcmp(varNames,'q_3'));

        % Convert quaternions to euler angles and store
        quat_angles = [q0, q1, q2, q3];
        euler_angles = q2e(quat_angles)*180.0/pi;
        data = [ data, euler_angles ];
        
    elseif contains(groupName,'vehicle_local_position_setpoint')
        % Add extra stuff to the labelling
        varNames  = [varNames; {'v'}];
        varUnits  = [varUnits; {'m/s' }];
        varFrames = [varFrames;{'earth'}];
        
        % Add total speed channel
        Vx = data(:,strcmp(varNames,'vx'));
        Vy = data(:,strcmp(varNames,'vy'));
        V = sqrt(Vx.*Vx + Vy.*Vy);
        data = [ data, V ];
        
    elseif contains(groupName,'vehicle_local_position')
        % Add extra stuff to the labelling
        varNames  = [varNames; {'v'}];
        varUnits  = [varUnits; {'m/s' }];
        varFrames = [varFrames;{'earth'}];
        
        % Add total speed channel
        Vx = data(:,strcmp(varNames,'vx'));
        Vy = data(:,strcmp(varNames,'vy'));
        V = sqrt(Vx.*Vx + Vy.*Vy);
        data = [ data, V ];
        
    elseif contains(groupName,'battery_status')
        % Add extra stuff to the labelling
        varNames  = [varNames; {'power'}; {'power_filtered'}];
        varUnits  = [varUnits; {'W'}; {'W'}];
        varFrames = [varFrames;{'N/A'}; {'N/A'}];
        
        % Find which variables to use
        V  = data(:,strcmp(varNames,'voltage_v'));
        I  = data(:,strcmp(varNames,'current_a'));
        Vf = data(:,strcmp(varNames,'voltage_filtered_v'));
        If = data(:,strcmp(varNames,'current_filtered_a'));
        
        % Add power into the system
        data = [ data, V.*I, Vf.*If ];
        
    elseif contains(groupName,'vehicle_gps_position')
        
        % Find which variables to use
        lat_pos = find(strcmp(varNames,'lat'));
        lon_pos = find(strcmp(varNames,'lon'));
        
        % Fix GPS data
        data(:,[lat_pos,lon_pos]) = data(:,[lat_pos,lon_pos]) ./ 1e7;
    end
    
    % Some channels are from embedded structures (denoted with __) - let's
    % re-embed them
    if max(contains(varNames,'__'))
        embeddedLog = struct();
        idx = find(contains(varNames,'__'));
                
        % Save the embedded data into a struct so we can deal with it later
        for jj = 1:numel(idx)
            varName = varNames{idx(jj)};
            loc = strfind(varName,'__');
            parentName = varName(1:loc-1);
            varName(1:loc+1) = [];

            % Save the data
            embeddedLog.(parentName).(varName).data  = data(:,idx(jj));
            embeddedLog.(parentName).(varName).unit  = varUnits(idx(jj));
            embeddedLog.(parentName).(varName).frame = varFrames(idx(jj));
         
        end
        
        % Clear out the fields we've embedded
        varNames(idx)  = [];
        varUnits(idx)  = [];
        varFrames(idx) = [];
        data(:,idx)    = [];
                
    end
      
    % Generate the kVIS data structure
    fds = kVIS_fdsAddTreeLeaf(fds, groupName, varNames, varNames, varUnits, varFrames, data, parentNode, false);
    
    % Embed any logs that we've found along the way
    if exist('embeddedLog','var')
        
        % Add leaves for the tempGroup stuff
        % Add each element of tempGroup into the fds
        parents = fieldnames(embeddedLog);
        parentID   = size(fds.fdata,2);
        
        for jj = 1:numel(parents)
            parentName = parents{jj};
            childNames = fieldnames(embeddedLog.(parentName));
            
            childData   = [];
            childUnits  = {};
            childFrames = {};
            
            for kk = 1:numel(childNames)
                childName = childNames{kk};
                childUnits(end+1,1)  = embeddedLog.(parentName).(childName).unit;
                childFrames(end+1,1) = embeddedLog.(parentName).(childName).frame;
                childData(:,end+1)   = embeddedLog.(parentName).(childName).data;
                                
            end
            
            % Correct the time stamp (assumed first)
            childNames{1} = 'Time';
            childUnits{1} = 's';
            childFrames{1} = '';
            childData(:,1) = childData(:,1) / 1e6;
             
            % Add the emmbeded data leaf (only if it contains data)
            if max(max(abs(childData(:,2:end)))) > 0
                fprintf('\t\tEmbedding %s\n',parentName);
                fds = kVIS_fdsAddTreeLeaf(fds, parentName, childNames, childNames, childUnits, childFrames, childData, parentID, false);
            else
                fprintf('\t\tSkipping  %s (empty)\n',parentName);
            end
        
        end
        
        % We're done with this data
        clear embeddedLog;
    end

end


%% Fix up the time so starts at t = 0
fds.timeOffset = t_start; t_end = t_end - t_start;
for ii = 2:numel(fds.fdata(1,:))
    fds.fdata{fds.fdataRows.data,ii}(:,1) = fds.fdata{fds.fdataRows.data,ii}(:,1) - fds.timeOffset;
end
    
%% Add events based on flight mode changes
% We can use MODE.ModeNum to work this out
modeTimes   = kVIS_fdsGetChannel(fds, 'manual_control_setpoint_0','Time');
modeNumbers = kVIS_fdsGetChannel(fds, 'manual_control_setpoint_0','mode_slot');
% modeReasons = kVIS_fdsGetChannel(fds, 'manual_control_setpoint_0','data_source');

modeTimes(1) = 0; % Force the first mode time to 0

% Combine short and same mode changes
if numel(modeTimes > 0.5)
    ii = 2;
    while ii < numel(modeNumbers)
        if modeNumbers(ii-1) == modeNumbers(ii)
            % Remove entry as mode didn't change
            modeNumbers(ii) = [];
            modeTimes(ii)   = [];
            % modeReasons(ii) = [];
        else
            ii = ii+1;
        end
    end
end

% Add a marker for the mode at log's end
modeTimes(end+1) = t_end;
modeNumbers(end+1) = modeNumbers(end);
% modeReasons(end+1) = modeReasons(end);

% Loop through modeTimes and store data
eventNumber = 0;

for ii = 1:numel(modeTimes)-1
    % Get info
    t_in  = modeTimes(ii);
    t_out = modeTimes(ii+1);
    
    % Check if change was valid
    if t_out-t_in > 0.5
        
        modeReason = 'Mode Switch';
        
        modeType = modes_PX4_Copter(modeNumbers(ii));
        
        % Fill out eList
        eventNumber = eventNumber+1;
        eList(eventNumber).type = modeType;
        eList(eventNumber).start= t_in;
        eList(eventNumber).end  = t_out;
        eList(eventNumber).description = modeReason;
        eList(eventNumber).plotDef='';
    end
        
end

% Add eList to eventList
fds.eventList = eList;

%% Return the fds struct
fprintf('File imported in %.2f seconds\n',toc);

return

end

function modeName = modes_PX4_Copter(modeNumber)
% From https://github.com/PX4/PX4-Autopilot/blob/master/src/modules/commander/px4_custom_mode.h#L45

% These don't seem to match up so who knows what's going on...

switch (modeNumber)
	case 1; modeName = 'MANUAL';
	case 2; modeName = 'ALTCTL';
	case 3; modeName = 'POSCTL';
	case 4; modeName = 'POSITION';
	case 5; modeName = 'OFFBOARD';
	case 6; modeName = 'LAND';
	case 7; modeName = 'STABILIZED';
	case 8; modeName = 'RATTITUDE_LEGACY';
	case 9; modeName = 'SIMPLE';
    otherwise; modeName = ['UNKNOWN_(',num2str(modeNumber),')'];
end
return
end

function euler_angles = q2e(q)
%
%
% Q2E converts Quaternions to roll-pitch-yaw (1-2-3) sequence Euler angles
%
% References:
% + Dan Newman: C130 Kalman Filter - checked
% + Diebel2006: Representing Attitude: Euler Angles, Unit Quaternions, and Rotation Vectors.pdf - checked
%
% Output angles in degrees

q0 = q(:,1);
q1 = q(:,2);
q2 = q(:,3);
q3 = q(:,4);

% convert quaternions to euler angles 1-2-3
phi   = atan2( 2*(q2.*q3 + q0.*q1), q0.^2 - q1.^2 - q2.^2 + q3.^2);
theta = asin(2*(q0.*q2 - q1.*q3));
psi   = atan2( 2*(q1.*q2 + q0.*q3), q0.^2 + q1.^2 - q2.^2 - q3.^2);

euler_angles = [phi,theta,psi];

return
end