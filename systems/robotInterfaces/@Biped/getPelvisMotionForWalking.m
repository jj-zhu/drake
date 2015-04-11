function pelvis_motion_data = getPelvisMotionForWalking(obj, foot_motion_data, supports, support_times, options)

if nargin < 6
  options = struct();
end
options = applyDefaults(options, struct('pelvis_height_above_sole', obj.default_walking_params.pelvis_height_above_foot_sole, 'debug', true));

if options.debug
  figure(321)
  clf
  subplot 211
  hold on
end

if options.debug
  lcmgl = LCMGLClient('swing_traj');
end

pelvis_reference_height = zeros(1,length(support_times));

T_sole_to_orig = struct('right', inv(obj.getFrame(obj.foot_frame_id.right).T),...
           'left', inv(obj.getFrame(obj.foot_frame_id.left).T));
T_frame_to_sole = T_sole_to_orig;
for j = 1:2
  frame_or_body_id = foot_motion_data(j).body_id;
  if frame_or_body_id > 0
    if frame_or_body_id == obj.foot_body_id.right
      T_frame_to_sole.right = T_sole_to_orig.right;
    else
      T_frame_to_sole.left = T_sole_to_orig.left;
    end
  else
    frame = obj.getFrame(frame_or_body_id);
    T_frame_to_orig = frame.T;
    if frame.body_ind == obj.foot_body_id.right
      T_frame_to_sole.right = T_frame_to_orig * T_sole_to_orig.right;
    else
      T_frame_to_sole.left = T_frame_to_orig * T_sole_to_orig.left;
    end
  end
end

if options.debug
  for i = 1:2
    ts = foot_motion_data(i).ts;
    tsample = linspace(ts(1), ts(end), 200);
    pp = foot_motion_data(i).getPP();
    xs = ppval(pp, tsample);
    foot_deriv_pp = fnder(pp);
    xds = ppval(foot_deriv_pp, tsample);
    figure(320)
    plot(tsample, xs);
    
    figure(321)
    plot(tsample, xs(3,:), 'b.-')
    xlim([0, ts(end)])

    lcmgl.glColor3f(0.2,0.9,0.2);
    lcmgl.glPointSize(5);
    lcmgl.points(xs(1,:), xs(2,:), xs(3,:));

    for j = 1:length(ts)
      pose = foot_motion_data(i).eval(ts(j));
      lcmgl.sphere(pose(1:3), 0.02, 10, 10);
    end

    vscale = 0.1;
    for j = 1:size(xs,2)
      lcmgl.line3(xs(1,j), xs(2,j), xs(3,j), ...
                  xs(1,j) + vscale*xds(1,j),...
                  xs(2,j) + vscale*xds(2,j),...
                  xs(3,j) + vscale*xds(3,j));
    end

    oldfig = gcf();
    figure(322)
    clf
    hold on
    plot(tsample, xds(1,:), 'r.-')
    plot(tsample, xds(2,:), 'g.-')
    plot(tsample, xds(3,:), 'b.-')
    sfigure(oldfig);
  end

  lcmgl.switchBuffers();
end

for j = 1:length(foot_motion_data)
  body_id = foot_motion_data(j).body_id;
  if body_id < 0
    body_id = obj.getFrame(body_id).body_ind;
  end
  if body_id == obj.foot_body_id.left
    lfoot_body_motion = foot_motion_data(j);
  elseif body_id == obj.foot_body_id.right
    rfoot_body_motion = foot_motion_data(j);
  end
end

lfoot_frame = lfoot_body_motion.eval(0);
T_l_frame = poseQuat2tform([lfoot_frame(1:3); expmap2quat(lfoot_frame(4:6))]);
lsole_des = tform2poseQuat(T_l_frame * T_frame_to_sole.left);

rfoot_frame = rfoot_body_motion.eval(0);
T_r_frame = poseQuat2tform([rfoot_frame(1:3); expmap2quat(rfoot_frame(4:6))]);
rsole_des = tform2poseQuat(T_r_frame * T_frame_to_sole.right);

pelvis_reference_height(1) = min(lsole_des(3),rsole_des(3));

for i=1:length(support_times)-1
  isDoubleSupport = any(supports(i).bodies==obj.foot_body_id.left) && any(supports(i).bodies==obj.foot_body_id.right);
  isRightSupport = ~any(supports(i).bodies==obj.foot_body_id.left) && any(supports(i).bodies==obj.foot_body_id.right);
  isLeftSupport = any(supports(i).bodies==obj.foot_body_id.left) && ~any(supports(i).bodies==obj.foot_body_id.right);
  if options.debug
    plot(support_times(i:i+1), 0.15 + 0.05*(isRightSupport|isDoubleSupport)*[1, 1], 'go:')
    plot(support_times(i:i+1), 0.15 + 0.05*(isLeftSupport|isDoubleSupport)*[1,1], 'ro:')
  end

  nextIsDoubleSupport = any(supports(i+1).bodies==obj.foot_body_id.left) && any(supports(i+1).bodies==obj.foot_body_id.right);
  nextIsRightSupport = ~any(supports(i+1).bodies==obj.foot_body_id.left) && any(supports(i+1).bodies==obj.foot_body_id.right);
  nextIsLeftSupport = any(supports(i+1).bodies==obj.foot_body_id.left) && ~any(supports(i+1).bodies==obj.foot_body_id.right);

  t = support_times(i);
  t_next = support_times(i+1);

  lfoot_frame = lfoot_body_motion.eval(t);
  T_l_frame = poseQuat2tform([lfoot_frame(1:3); expmap2quat(lfoot_frame(4:6))]);
  lsole_des = tform2poseQuat(T_l_frame * T_frame_to_sole.left);

  rfoot_frame = rfoot_body_motion.eval(t);
  T_r_frame = poseQuat2tform([rfoot_frame(1:3); expmap2quat(rfoot_frame(4:6))]);
  rsole_des = tform2poseQuat(T_r_frame * T_frame_to_sole.right);

  lfoot_frame_next = lfoot_body_motion.eval(t_next);
  T_l_frame_next = poseQuat2tform([lfoot_frame_next(1:3); expmap2quat(lfoot_frame_next(4:6))]);
  lsole_des_next = tform2poseQuat(T_l_frame_next * T_frame_to_sole.left);

  rfoot_frame_next = rfoot_body_motion.eval(t_next);
  T_r_frame_next = poseQuat2tform([rfoot_frame_next(1:3); expmap2quat(rfoot_frame_next(4:6))]);
  rsole_des_next = tform2poseQuat(T_r_frame_next * T_frame_to_sole.right);

  step_height_delta_threshold = 0.025; % cm, min change in height to classify step up/down
  step_up_pelvis_shift = 0.03; % cm
  if isDoubleSupport && nextIsDoubleSupport
    pelvis_reference_height(i+1) = pelvis_reference_height(i);
  elseif isDoubleSupport && nextIsLeftSupport
    if lsole_des_next(3) > rsole_des(3) + step_height_delta_threshold
      % stepping up with left foot
      pelvis_reference_height(i+1) = lsole_des_next(3)-step_up_pelvis_shift;
    else
      pelvis_reference_height(i+1) = lsole_des_next(3);
    end
  elseif isDoubleSupport && nextIsRightSupport

    if rsole_des_next(3) > lsole_des(3) + step_height_delta_threshold
      % stepping up with right foot
      pelvis_reference_height(i+1) = rsole_des_next(3)-step_up_pelvis_shift;
    else
      pelvis_reference_height(i+1) = rsole_des_next(3);
    end
  elseif isLeftSupport && nextIsDoubleSupport 
    if rsole_des_next(3) < lsole_des(3) - step_height_delta_threshold
      % stepping down with right foot
      pelvis_reference_height(i+1) = rsole_des_next(3)-step_up_pelvis_shift;
    else
      pelvis_reference_height(i+1) = lsole_des(3);
    end
  elseif isRightSupport && nextIsDoubleSupport 
    if lsole_des_next(3) < rsole_des(3) - step_height_delta_threshold
      % stepping down with left foot
      pelvis_reference_height(i+1) = lsole_des_next(3)-step_up_pelvis_shift;
    else
      pelvis_reference_height(i+1) = rsole_des(3);
    end
  end
end

% Now set the pelvis reference
pelvis_body = obj.findLinkId('pelvis');
pelvis_ts = support_times;

rpos = ppval(rfoot_body_motion.getPP(), pelvis_ts);
lpos = ppval(lfoot_body_motion.getPP(), pelvis_ts);

pelvis_yaw = zeros(1, numel(pelvis_ts));

for j = 1:numel(pelvis_ts)
  rrpy = quat2rpy(expmap2quat(rpos(4:6,j)));
  lrpy = quat2rpy(expmap2quat(lpos(4:6,j)));
  pelvis_yaw(j) = angleAverage(rrpy(3), lrpy(3));
end
pelvis_yaw = unwrap(pelvis_yaw);


pelvis_poses_rpy = [nan(2, size(rpos, 2));
                pelvis_reference_height + options.pelvis_height_above_sole;
                zeros(2, numel(pelvis_ts));
                pelvis_yaw];

pp = foh(pelvis_ts, pelvis_poses_rpy);
pelvis_motion_data = BodyMotionData.from_body_xyzrpy_pp(pelvis_body, pp);

if options.debug
  pp = pelvis_motion_data.getPP();
  tt = linspace(pelvis_ts(1), pelvis_ts(end), 100);
  ps = ppval(pp, tt);
  figure(25)
  plot(tt, ps);
end
