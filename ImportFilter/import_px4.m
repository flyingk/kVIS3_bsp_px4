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

if file==0
    warning('Error loading file.')
    return
end

tic

fprintf('Importing PX4 .ulg file\n');
fprintf('\t%s\n\n',file);

%% get new fds structure
fds = kVIS_fdsInitNew();

fds.BoardSupportPackage = 'PX4';

[fds, parentNode] = kVIS_fdsAddTreeBranch(fds, 0, 'PX4_data');


%% Convert ulg into csv files
[path, file, extension] = fileparts(file); ...
    path = [path,'\'];

csv_folder = [path,'csv_',file];
mkdir([path,'csv_',file]);

% Convert file to CSV
evalc(['!ulog2csv -o ',[path,'csv_',file,'\'],' ',[path,file,extension]]);

%% read data
% Loop through each file in the csv folder
csv_files = dir([csv_folder,'\**\*.csv']);

t_min = inf;

for ii = 1:length(csv_files)
    % Print debug stuff
    data_path = csv_files(ii).folder;
    data_file = csv_files(ii).name;
    fprintf('Found file  << %s >>\n',data_file);
    
    % Get data stream name
    groupName = csv_files(ii).name(length(file)+2:end-4);
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
    
    % Add special fields that PX4 doesn't normally have (because it's stupid)
    if strcmp(groupName,'vehicle_attitude_0')
        % Add extra stuff to the labelling
        varNames  = [varNames; {'roll'};{'pitch'};{'yaw' }];
        varUnits  = [varUnits; {'deg' };{'deg'  };{'deg' }];
        varFrames = [varFrames;{'body'};{'body' };{'body'}];
        
        % Convert quaternions to euler angles and store
        quat_angles = DAT(:,5:8);
        euler_angles = q2e(quat_angles)*180.0/pi;
        DAT = [ DAT, euler_angles ];
        
        % Take t_min from the attitude data
         t_min = min(t_min,DAT(1,1));
        
    end
    
    if strcmp(groupName,'vehicle_attitude_setpoint_0')
        % Add extra stuff to the labelling
        varNames  = [varNames; {'roll_d'};{'pitch_d'};{'yaw_d' }];
        varUnits  = [varUnits; {'deg' };{'deg'  };{'deg' }];
        varFrames = [varFrames;{'body'};{'body' };{'body'}];
        
        % Convert quaternions to euler angles and store
        quat_angles = DAT(:,6:9);
        euler_angles = q2e(quat_angles)*180.0/pi;
        DAT = [ DAT, euler_angles ];
        
    end

    if strcmp(groupName,'vehicle_local_position_0')
        % Add extra stuff to the labelling
        varNames  = [varNames; {'v'}];
        varUnits  = [varUnits; {'m/s' }];
        varFrames = [varFrames;{'earth'}];
        
        % Convert quaternions to euler angles and store
        Vx = DAT(:,11);
        Vy = DAT(:,12);
        V = sqrt(Vx.*Vx + Vy.*Vy);
        DAT = [ DAT, V ];
        
    end
    
    if strcmp(groupName,'vehicle_local_position_setpoint_0')
        % Add extra stuff to the labelling
        varNames  = [varNames; {'v'}];
        varUnits  = [varUnits; {'m/s' }];
        varFrames = [varFrames;{'earth'}];
        
        % Convert quaternions to euler angles and store
        Vx = DAT(:,7);
        Vy = DAT(:,8);
        V = sqrt(Vx.*Vx + Vy.*Vy);
        DAT = [ DAT, V ];
        
    end
    
    if strcmp(groupName,'battery_status_0')
        % Add extra stuff to the labelling
        varNames  = [varNames; {'power'}; {'power_filtered'}];
        varUnits  = [varUnits; {'W'}; {'W'}];
        varFrames = [varFrames;{'N/A'}; {'N/A'}];
        
        % Add power into the system
        DAT = [ DAT, DAT(:,2).*DAT(:,4), DAT(:,3).*DAT(:,5) ];
        
    end
         
    if strcmp(groupName,'vehicle_gps_position_0')
        % Fix GPS data
        DAT(:,3:4) = DAT(:,3:4) ./ 1e7;
    end
    
    
    % Generate the kVIS data structure
    fds = kVIS_fdsAddTreeLeaf(fds, groupName, varNames, varNames, varUnits, varFrames, DAT, parentNode, false);
        
end

% Remove the csv folder
rmdir([path,'csv_',file],'s');

% Correct all the time vectors
for ii = 1:length(csv_files)
    fds.fdata{7,ii+1}(:,1) = (fds.fdata{7,ii+1}(:,1) - t_min)/1e6;
    
end

%% Return the fds struct
return

