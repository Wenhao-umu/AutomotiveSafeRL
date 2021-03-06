# train a policy to solve the car mdp without masking

rng = MersenneTwister(1)
using AutomotivePOMDPs
using MDPModelChecking
using GridInterpolations
using StaticArrays
using POMDPs
using POMDPModelTools
using AutoViz
using AutomotiveDrivingModels
using Reel
using DeepQLearning
using RLInterface
using DiscreteValueIteration
using ProgressMeter
using Parameters
using JLD

include("util.jl")

params = UrbanParams(nlanes_main=1,
                     crosswalk_pos =  [VecSE2(6, 0., pi/2), VecSE2(-6, 0., pi/2), VecSE2(0., -5., 0.)],
                     crosswalk_length =  [14.0, 14., 14.0],
                     crosswalk_width = [4.0, 4.0, 3.1],
                     stop_line = 22.0)
env = UrbanEnv(params=params)
pomdp = UrbanPOMDP(env=env,
                   ego_goal = LaneTag(2, 1),
                   max_cars=1, 
                   max_peds=0, 
                   car_birth=0.7, 
                   ped_birth=0.7, 
                   obstacles=false, # no fixed obstacles
                   lidar=false,
                   pos_obs_noise = 0., # fully observable
                   vel_obs_noise = 0.);
pomdp.collision_cost = -1.
# pomdp.goal_reward = 0.1


max_steps = 500000
eps_fraction = 0.5 
eps_end = 0.01 
solver = DeepQLearningSolver(max_steps = max_steps, eps_fraction = eps_fraction, eps_end = eps_end,
                       lr = 0.0001,                    
                       batch_size = 32,
                       target_update_freq = 5000,
                       max_episode_length = 200,
                       train_start = 40000,
                       buffer_size = 400000,
                       eval_freq = 10000,
                       arch = QNetworkArchitecture(conv=[], fc=[32,32,32]),
                       double_q = true,
                       dueling = true,
                       prioritized_replay = true,
                       verbose = true,
                       logdir = "carmdp-log/log_nm8",
                       rng = rng)

policy = solve(solver, POMDPEnvironment(pomdp))

# evaluate resulting policy
@time rewards_mask, steps_mask, violations_mask = evaluation_loop(pomdp, policy, n_ep=1000, max_steps=100, rng=rng);
print_summary(rewards_mask, steps_mask, violations_mask)
