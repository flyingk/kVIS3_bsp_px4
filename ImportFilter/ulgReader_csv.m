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

function fds = ulg_import_csv(file)

if ~nargin
    root_dir = 'C:\Users\matt\Documents\kVIS\kVIS3_bsp_px4\Sample_Data';
    file = 'log_28_2021-4-2-16-38-26.ulg';  % Small (0.5 MB)
%     file = 'log_13_2019-9-14-02-08-36.ulg'; % Medium (7 MB)
%     file = 'log_0_2019-9-13-16-25-54.ulg';  % Large (25 MB)

   file = fullfile(root_dir,file);

end

tic

fprintf('Importing PX4 .ulg file\n');
fprintf('\t%s\n\n',file);


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
    varNames = data.Properties.VariableNames'; 
    n_channels = numel(varNames);
    
    fds.logs.(groupName) = struct();
    
%     keyboard
    
    % Import the data
    DAT = nan(size(data));
    for jj = 1:numel(varNames)
        % I've got this importing individual rows here in case we want to
        % preserve any non-numeric data and put it somewhere
        %fprintf('\t\tFound channel %50s\n', varNames{jj});
        varName = varNames{jj};

        % Remove trailing underscores
        if strcmp(varNames(end),'_')
            varName = varName(1:end-1);
        end
        
        % Add data to struct
        new_data = table2array(data(:,jj));
        fds.logs.(groupName).(varName) = new_data;
             
    end

end

% Remove the csv folder
rmdir(csv_folder,'s');

% Remove the padding from the files
fds = remove_padding(fds);


%% Return the fds struct
fprintf('File imported in %.2f seconds\n',toc);

return

end

function data = remove_padding(data)
% Removes the padding terms from the generated structs

logs = fieldnames(data.logs);

for ii = 1:numel(logs)
    log = logs{ii};
    channels = fieldnames(data.logs.(log));
    
    for jj = 1:numel(channels)
        channel = channels{jj};
        
        if contains(channel,'padding0')
            data.logs.(log) = rmfield(data.logs.(log),channel);

        end
    end
end

% The data struct should now have all the padding removed

return
end

