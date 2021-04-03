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
    file = 'log_13_2019-9-14-02-08-36.ulg';
    file = 'log_28_2021-4-2-16-38-26.ulg';
end

tic

fprintf('Importing PX4 .ulg file\n');
fprintf('\t%s\n\n',file);

%% get new fds structure
fds = kVIS_fdsInitNew();

fds.BoardSupportPackage = 'PX4';

[fds, parentNode] = kVIS_fdsAddTreeBranch(fds, 0, 'PX4_data');


%% Convert ulg into csv files
[path, file_root] = fileparts(file); ...

csv_folder = fullfile(path,['csv_',file_root]);
mkdir(csv_folder);

% Convert file to CSV
cmd = ['!ulog2csv -o ',csv_folder,'\ ',file];
evalc(cmd);

%% read data
% Loop through each file in the csv folder
csv_files = dir([csv_folder,'\**\*.csv']);

% Warn if no files created
if (isempty(csv_files))
    fprintf('\n\n***************************************\n\n');
    fprintf('pyulog (or python) may not be installed properly.  Check that you can manually convert .ulg files to csv\n\n');
    fprintf('    (spaces in file names are bad too...)\n');
    fprintf('\t%s\n',cmd)
    fprintf('\n\n***************************************\n\n');
    keyboard
end

t_start = inf;
t_end = -inf;

for ii = 1:length(csv_files)
    % Print debug stuff
    data_path = csv_files(ii).folder;
    data_file = csv_files(ii).name;
    fprintf('Found file  << %s >>\n',data_file);
    
    % Get data stream name
    groupName = csv_files(ii).name(length(file_root)+2:end-4);
    fprintf('\tImporting field %s\n',groupName);
    
    % Get all the headers and stuff
    data = readtable([data_path,'\',data_file]);
    varNames = data.Properties.VariableNames'; ...
        varNames{1} = 'Time';
    n_channels = numel(varNames);
    
    varUnits = repmat({'N/A'}, n_channels,1); ...
        varUnits{1} = 's';
    varFrames = repmat({'Unknown Frame'}, n_channels,1);
    
    % Import the data
    DAT = nan(size(data));
    for jj = 1:numel(varNames)
        % I've got this importing individual rows here in case we want to
        % preserve any non-numeric data and put it somewhere
        %fprintf('\t\tFound channel %50s\n', varNames{jj});
        DAT(:,jj) = table2array(data(:,jj));
        
        % Remove trailing underscores
        if strcmp(varNames{jj}(end),'_')
            varNames{jj} = varNames{jj}(1:end-1);
        end
        
        
            
    end
    
    % Convert the time element to seconds
    DAT(:,1) = DAT(:,1) / 1e6;
    
    % Find t_start and t_end
    t_start = min(t_start,DAT(1,1));
    t_end   = max(t_end  ,DAT(end,1));
    
    % Add special fields that PX4 doesn't normally have (because it's stupid)
    if strcmp(groupName,'vehicle_attitude_0')
        % Add extra stuff to the labelling
        varNames  = [varNames; {'roll'};{'pitch'};{'yaw' }];
        varUnits  = [varUnits; {'deg' };{'deg'  };{'deg' }];
        varFrames = [varFrames;{'body'};{'body' };{'body'}];
        
        % Find which variables to use
        q0 = DAT(:,strcmp(varNames,'q_0'));
        q1 = DAT(:,strcmp(varNames,'q_1'));
        q2 = DAT(:,strcmp(varNames,'q_2'));
        q3 = DAT(:,strcmp(varNames,'q_3'));
        
        % Convert quaternions to euler angles and store
        quat_angles = [q0, q1, q2, q3];
        euler_angles = q2e(quat_angles)*180.0/pi;
        DAT = [ DAT, euler_angles ];
        
    end
    
    if strcmp(groupName,'vehicle_attitude_setpoint_0')
        % Add extra stuff to the labelling
        varNames  = [varNames; {'roll_d'};{'pitch_d'};{'yaw_d' }];
        varUnits  = [varUnits; {'deg' };{'deg'  };{'deg' }];
        varFrames = [varFrames;{'body'};{'body' };{'body'}];
        
        % Find which variables to use
        q0c = DAT(:,strcmp(varNames,'q_d_0'));
        q1c = DAT(:,strcmp(varNames,'q_d_1'));
        q2c = DAT(:,strcmp(varNames,'q_d_2'));
        q3c = DAT(:,strcmp(varNames,'q_d_3'));
        
        % Convert quaternions to euler angles and store
        quat_angles = [q0c, q1c, q2c, q3c];
        euler_angles = q2e(quat_angles)*180.0/pi;
        DAT = [ DAT, euler_angles ];
        
    end

    if strcmp(groupName,'vehicle_local_position_0')
        % Add extra stuff to the labelling
        varNames  = [varNames; {'v'}];
        varUnits  = [varUnits; {'m/s' }];
        varFrames = [varFrames;{'earth'}];
        
        % Add total speed channel
        Vx = DAT(:,strcmp(varNames,'vx'));
        Vy = DAT(:,strcmp(varNames,'vy'));
        V = sqrt(Vx.*Vx + Vy.*Vy);
        DAT = [ DAT, V ];
        
    end
    
    if strcmp(groupName,'vehicle_local_position_setpoint_0')
        % Add extra stuff to the labelling
        varNames  = [varNames; {'v'}];
        varUnits  = [varUnits; {'m/s' }];
        varFrames = [varFrames;{'earth'}];
        
        % Add total speed channel
        Vx = DAT(:,strcmp(varNames,'vx'));
        Vy = DAT(:,strcmp(varNames,'vy'));
        V = sqrt(Vx.*Vx + Vy.*Vy);
        DAT = [ DAT, V ];
        
    end
    
    if strcmp(groupName,'battery_status_0')
        % Add extra stuff to the labelling
        varNames  = [varNames; {'power'}; {'power_filtered'}];
        varUnits  = [varUnits; {'W'}; {'W'}];
        varFrames = [varFrames;{'N/A'}; {'N/A'}];
        
        % Find which variables to use
        V = DAT(:,strcmp(varNames,'voltage_v'));
        I = DAT(:,strcmp(varNames,'current_a'));
        Vf = DAT(:,strcmp(varNames,'voltage_filtered_v'));
        If = DAT(:,strcmp(varNames,'current_filtered_a'));
        
        % Add power into the system
        DAT = [ DAT, V.*I, Vf.*If ];
        
    end
         
    if strcmp(groupName,'vehicle_gps_position_0')
        
        % Find which variables to use
        lat_pos = find(strcmp(varNames,'lat'));
        lon_pos = find(strcmp(varNames,'lon'));
        
        % Fix GPS data
        DAT(:,[lat_pos,lon_pos]) = DAT(:,[lat_pos,lon_pos]) ./ 1e7;
    end
    
    
    % Generate the kVIS data structure
    fds = kVIS_fdsAddTreeLeaf(fds, groupName, varNames, varNames, varUnits, varFrames, DAT, parentNode, false);
        
end

% Remove the csv folder
rmdir(csv_folder,'s');

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
	case 6; modeName = 'OFFBOARD';
	case 7; modeName = 'STABILIZED';
	case 8; modeName = 'RATTITUDE_LEGACY';
	case 9; modeName = 'SIMPLE';
    otherwise; modeName = ['UNKNOWN_(',num2str(modeNumber),')'];
end
return
end
