% Create a snap block for capturing snapshots in various interesting ways.
%
% snapshot_init(blk, varargin)
%
% blk = The block to be configured.
% varargin = {'varname', 'value', ...} pairs
%
% Valid varnames for this block are:
% nsamples = size of buffer (2^nsamples)
% data_width = the data width [8, 16, 32, 64, 128] 
% use_dsp48 = Use DSP48s to implement counters
% circap = support continual capture after trigger until stop seen
% offset = support delaying capture for configurable number of samples
% value = capture value on input port at same time as data capture starts

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                             %
%   Meerkat telescope project                                                 %
%   http://www.kat.ac.za                                                      %
%   Copyright 2011 Andrew Martens                                             %
%                                                                             %
%   This program is free software; you can redistribute it and/or modify      %
%   it under the terms of the GNU General Public License as published by      %
%   the Free Software Foundation; either version 2 of the License, or         %
%   (at your option) any later version.                                       %
%                                                                             %
%   This program is distributed in the hope that it will be useful,           %
%   but WITHOUT ANY WARRANTY; without even the implied warranty of            %
%   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the             %
%   GNU General Public License for more details.                              %
%                                                                             %
%   You should have received a copy of the GNU General Public License along   %
%   with this program; if not, write to the Free Software Foundation, Inc.,   %
%   51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.               %
%                                                                             %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function snapshot_init(blk,varargin)

clog('entering snapshot_init', 'trace');
check_mask_type(blk, 'snapshot');
munge_block(blk, varargin{:});

defaults = {'nsamples', 9, 'data_width', 32, 'use_dsp48', 'on' ...
  'circap', 'on', 'offset', 'on', 'value', 'off'};
if same_state(blk, 'defaults', defaults, varargin{:}), return, end
clog('snapshot_init: post same_state', 'trace');

nsamples = get_var('nsamples', 'defaults', defaults, varargin{:});
data_width = get_var('data_width', 'defaults', defaults, varargin{:});
use_dsp48 = get_var('use_dsp48', 'defaults', defaults, varargin{:});
circap = get_var('circap', 'defaults', defaults, varargin{:});
offset = get_var('offset', 'defaults', defaults, varargin{:});
value = get_var('value', 'defaults', defaults, varargin{:});

%useful constants
if strcmp(circap,'on'), circ = 1; else, circ = 0; end
if strcmp(offset,'on'), off = 1; else, off = 0; end
if strcmp(value,'on'), val = 1; else, val = 0; end

delete_lines(blk);

%basic input ports
reuse_block(blk, 'din', 'built-in/inport', 'Position', [130 247 160 263], 'Port', '1');
reuse_block(blk, 'slice', 'xbsIndex_r4/Slice', ...
  'nbits', num2str(data_width), 'mode', 'Lower Bit Location + Width', ...
  'bit0', '0', 'base0', 'LSB of Input', ...
  'Position', [190 247 220 263]); 
add_line(blk, 'din/1', 'slice/1');
reuse_block(blk, 'ri', 'xbsIndex_r4/Reinterpret', ...
  'force_arith_type', 'on', 'arith_type', 'Unsigned', ...
  'force_bin_pt', 'on', 'bin_pt', '0', ...
  'Position', [250 247 320 263]); 
add_line(blk, 'slice/1', 'ri/1');
reuse_block(blk, 'trig', 'built-in/inport', 'Position', [200 327 230 343], 'Port', '2');
reuse_block(blk, 'we', 'built-in/inport', 'Position', [200 287 230 303], 'Port', '3');

%basic_ctrl
clog('basic_ctrl block', 'snapshot_init_detailed_trace');
reuse_block(blk, 'basic_ctrl', 'casper_library_scopes/snapshot/basic_ctrl', ...
  'Position', [345 195 400 395]);
add_line(blk, 'ri/1', 'basic_ctrl/2');
add_line(blk, 'we/1', 'basic_ctrl/3');
add_line(blk, 'trig/1', 'basic_ctrl/4');

%ctrl reg
reuse_block(blk, 'const0', 'built-in/Constant', 'Value', '0', 'Position', [130 365 150 385]);
reuse_block(blk, 'ctrl', 'xps_library/software register', ...
  'io_dir', 'From Processor', 'arith_type', 'Unsigned', ...
  'Position', [165 360 265 390]);
add_line(blk, 'const0/1', 'ctrl/1');
add_line(blk, 'ctrl/1', 'basic_ctrl/5');

% stop_gen block

reuse_block(blk, 'g_tr_en_cnt', 'built-in/Terminator', ...
  'Position', [1190 397 1205 413]);

if circ == 1,
  clog('stop_gen block', 'snapshot_init_detailed_trace');

  reuse_block(blk, 'stop', 'built-in/inport', 'Position', [200 407 230 423], 'Port', '4');
  reuse_block(blk, 'stop_gen', 'casper_library_scopes/snapshot/stop_gen', ...
    'Position', [485 200 540 430]);
  add_line(blk, 'stop/1', 'stop_gen/6');
  
  %join basic ctrl
  add_line(blk, 'basic_ctrl/1', 'stop_gen/1'); %vin
  add_line(blk, 'basic_ctrl/2', 'stop_gen/2'); %din
  add_line(blk, 'basic_ctrl/3', 'stop_gen/3'); %we
  add_line(blk, 'basic_ctrl/5', 'stop_gen/4'); %init
  add_line(blk, 'ctrl/1', 'stop_gen/5'); %ctrl

  %tr_en_cnt register 
  reuse_block(blk, 'tr_en_cnt', 'xps_library/software register', ...
    'io_dir', 'To Processor', 'arith_type', 'Unsigned', ...
    'Position', [1070 390 1170 420]);

  add_line(blk, 'tr_en_cnt/1', 'g_tr_en_cnt/1');

else
% constant so that always stop
  reuse_block(blk, 'never', 'xbsIndex_r4/Constant', ...
    'arith_type', 'Boolean', 'const', '0', 'explicit_period', 'on', 'period', '1', ...
    'Position', [600 340 620 360]);
  
end

%delay_block
%TODO could support offset in stop time too
if off == 1,
  clog('delay block', 'snapshot_init_detailed_trace');
  
  % offset register
  reuse_block(blk, 'const1', 'built-in/Constant', 'Value', '10', 'Position', [130 500 150 520]);
  reuse_block(blk, 'trig_offset', 'xps_library/software register', ...
    'io_dir', 'From Processor', 'arith_type', 'Unsigned', ...
    'Position', [165 495 265 525]);
  add_line(blk, 'const1/1', 'trig_offset/1');

  % block doing delay
  reuse_block(blk, 'delay', 'casper_library_scopes/snapshot/delay', ...
    'use_dsp48', use_dsp48, 'Position', [650 215 715 420]);
  add_line(blk, 'trig_offset/1', 'delay/7');

  add_line(blk, 'basic_ctrl/5', 'delay/5'); %init
  add_line(blk, 'basic_ctrl/4', 'delay/4'); %go  
  %join up to stop 
  if circ == 1,
    add_line(blk, 'stop_gen/1', 'delay/1'); %vin
    add_line(blk, 'stop_gen/2', 'delay/2'); %din
    add_line(blk, 'stop_gen/3', 'delay/3'); %we
    add_line(blk, 'stop_gen/4', 'delay/6'); %continue 
  else, % or basic block
    add_line(blk, 'basic_ctrl/1', 'delay/1'); %vin
    add_line(blk, 'basic_ctrl/2', 'delay/2'); %din
    add_line(blk, 'basic_ctrl/3', 'delay/3'); %we
    add_line(blk, 'never/1', 'delay/6'); %continue
    
  end
else,
% don't really have anything to do if no offset  
end

%add_gen block

% address counter must be full 32 for circular capture
% as used to track offset into vector
if circ == 1,
  as = '32';
else
  as = 'nsamples+1';
end

clog('add_gen block', 'snapshot_init_detailed_trace');
reuse_block(blk, 'add_gen', 'casper_library_scopes/snapshot/add_gen', ...
  'nsamples', 'nsamples', 'counter_size', as, ...
  'use_dsp48', use_dsp48, 'Position', [800 210 860 420]);

% join add_gen to: delay block
if off == 1, 
  add_line(blk, 'delay/1', 'add_gen/1'); %vin 
  add_line(blk, 'delay/2', 'add_gen/2'); %din 
  add_line(blk, 'delay/3', 'add_gen/3'); %we 
  add_line(blk, 'delay/4', 'add_gen/4'); %go  
  add_line(blk, 'delay/5', 'add_gen/5'); %cont 
  add_line(blk, 'delay/6', 'add_gen/6'); %int 

% or stop_gen block
elseif circ == 1,
  add_line(blk, 'stop_gen/1', 'add_gen/1'); %vin 
  add_line(blk, 'stop_gen/2', 'add_gen/2'); %din 
  add_line(blk, 'stop_gen/3', 'add_gen/3'); %we 
  add_line(blk, 'basic_ctrl/4', 'add_gen/4'); %go  
  add_line(blk, 'stop_gen/4', 'add_gen/5'); %cont 
  add_line(blk, 'basic_ctrl/5', 'add_gen/6'); %init 

% or basic block
else
  add_line(blk, 'basic_ctrl/1', 'add_gen/1'); %vin 
  add_line(blk, 'basic_ctrl/2', 'add_gen/2'); %din 
  add_line(blk, 'basic_ctrl/3', 'add_gen/3'); %we 
  add_line(blk, 'basic_ctrl/4', 'add_gen/4'); %go 
  add_line(blk, 'basic_ctrl/5', 'add_gen/6'); %init 
  add_line(blk, 'never/1', 'add_gen/5'); %cont
end

% status registers
reuse_block(blk, 'addr', 'xps_library/software register', ...
  'io_dir', 'To Processor', 'arith_type', 'Unsigned', ...
  'Position', [895 355 995 385]);
add_line(blk, 'add_gen/5', 'addr/1');
reuse_block(blk, 'gaddr', 'built-in/Terminator', ...
  'Position', [1010 360 1025 375]);
add_line(blk, 'addr/1', 'gaddr/1');

%value in 
if val == 1,
  clog('value in', 'snapshot_init_detailed_trace');
  reuse_block(blk, 'vin', 'built-in/inport', 'Position', [200 207 230 223], 'Port', num2str(3+circ+1));
  add_line(blk, 'vin/1', 'basic_ctrl/1');

  % register
  reuse_block(blk, 'val', 'xps_library/software register', ...
    'io_dir', 'To Processor', 'arith_type', 'Unsigned', ...
    'Position', [895 215 995 245]);
  add_line(blk, 'add_gen/1', 'val/1');
  reuse_block(blk, 'gval', 'built-in/Terminator', ...
    'Position', [1010 223 1025 238]);
  add_line(blk,'val/1', 'gval/1'); 

else %connect constant and terminate output
  
  reuse_block(blk, 'vin_const', 'xbsIndex_r4/Constant', ...
    'arith_type', 'Boolean', 'const', '0', 'explicit_period', 'on', 'period', '1', ...
    'Position', [200 207 230 223]);
  add_line(blk, 'vin_const/1', 'basic_ctrl/1');
  reuse_block(blk, 'gval', 'built-in/Terminator', ...
    'Position', [1138 223 1153 238]);
  add_line(blk,'add_gen/1', 'gval/1'); 
  
end

if circ == 1,
  add_line(blk, 'add_gen/6', 'tr_en_cnt/1');
else
  add_line(blk, 'add_gen/6', 'g_tr_en_cnt/1');
end

%storage
clog('storage', 'snapshot_init_detailed_trace');
reuse_block(blk, 'add_del', 'xbsIndex_r4/Delay', ...
  'latency', '1', 'Position', [1025 255 1050 275]);
add_line(blk, 'add_gen/2', 'add_del/1'); %add
reuse_block(blk, 'dat_del', 'xbsIndex_r4/Delay', ...
  'latency', '1', 'Position', [1025 290 1050 310]);
add_line(blk, 'add_gen/3', 'dat_del/1'); %data
reuse_block(blk, 'we_del', 'xbsIndex_r4/Delay', ...
  'latency', '1', 'Position', [1025 325 1050 345]);
add_line(blk, 'add_gen/4', 'we_del/1'); %we

%shared BRAM
reuse_block(blk, 'bram', 'xps_library/Shared BRAM', ...
  'data_width', num2str(data_width), 'addr_width', num2str(nsamples), ...
  'Position', [1070 250 1170 350]);
add_line(blk, 'add_del/1', 'bram/1');
add_line(blk, 'dat_del/1', 'bram/2');
add_line(blk, 'we_del/1', 'bram/3');

reuse_block(blk, 'gbram', 'built-in/Terminator', ...
  'Position', [1190 290 1205 305]);
add_line(blk, 'bram/1', 'gbram/1');

% When finished drawing blocks and lines, remove all unused blocks.
clean_blocks(blk);

% Set attribute format string (block annotation)
annotation=sprintf('');
set_param(blk,'AttributesFormatString',annotation);

save_state(blk, 'defaults', defaults, varargin{:});  % Save and back-populate mask parameter values

clog('exiting snapshot_init', 'trace');