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

function [] = import_px4(hObject, ~)

% PX4 Log file
[file, pathname] = uigetfile('*.ulg');

% Load file
if file==0
    disp('Error loading file.')
    return
else
    file = fullfile(pathname,file);
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
    varNames = data.Properties.VariableNames;
    n_channels = numel(varNames);
    
    varUnits = repmat({'N/A'}, n_channels,1);
    varFrames = repmat({'Unknown Frame'}, n_channels,1);
    
    % Import the data
    DAT = nan(size(data));
    for jj = 1:numel(varNames)
        % I've got this importing individual rows here in case we want to
        % preserve any non-numeric data and put it somewhere
        fprintf('\t\tFound channel %50s\n', varNames{jj});
        DAT(:,jj) = table2array(data(:,jj));
    end
    
    % Generate the kVIS data structure
    fds = kVIS_fdsAddTreeLeaf(fds, groupName, varNames, varNames, varUnits, varFrames, DAT, parentNode, false);
        
end

% Remove the csv folder
rmdir([path,'csv_',file],'s');

%% Update KSID
fds = kVIS_fdsUpdateAttributes(fds);

fds = kVIS_fdsGenerateTexLabels(fds);

kVIS_addDataSet(hObject, fds, []);

return

