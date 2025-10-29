#!/usr/bin/env python3
"""
Custom Ansible callback plugin for better progress visualization
"""

from ansible.plugins.callback.default import CallbackModule as DefaultCallback
import sys
import time

class CallbackModule(DefaultCallback):
    CALLBACK_VERSION = 2.0
    CALLBACK_TYPE = 'stdout'
    CALLBACK_NAME = 'progress'

    def __init__(self):
        super(CallbackModule, self).__init__()
        self.start_time = time.time()
        self.task_count = 0
        self.completed_tasks = 0

    def v2_playbook_on_task_start(self, task, is_conditional):
        self.task_count += 1
        elapsed = time.time() - self.start_time
        print(f"\n🚀 [{self.task_count}] {task.get_name()}")
        print(f"⏱️  Elapsed: {elapsed:.1f}s")

    def v2_runner_on_ok(self, result):
        self.completed_tasks += 1
        progress = (self.completed_tasks / self.task_count) * 100
        elapsed = time.time() - self.start_time
        
        # Animated progress bar
        bar_length = 30
        filled_length = int(bar_length * self.completed_tasks // self.task_count)
        bar = '█' * filled_length + '░' * (bar_length - filled_length)
        
        # Add spinning indicator
        spinner = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'][int(time.time() * 4) % 10]
        
        print(f"\r{spinner} [{bar}] {progress:.1f}% ({self.completed_tasks}/{self.task_count}) - {elapsed:.1f}s", end='', flush=True)

    def v2_runner_on_failed(self, result, ignore_errors=False):
        self.completed_tasks += 1
        print(f"\n❌ FAILED: {result.task_name}")
        if hasattr(result, 'stderr') and result.stderr:
            print(f"📝 Error: {result.stderr}")
        if hasattr(result, 'stdout') and result.stdout:
            print(f"📄 Output: {result.stdout}")
        if hasattr(result, 'msg') and result.msg:
            print(f"💬 Message: {result.msg}")
        # Call parent method to show full error details
        super().v2_runner_on_failed(result, ignore_errors)
        
    def v2_playbook_on_stats(self, stats):
        total_time = time.time() - self.start_time
        print(f"\n🎉 Deployment completed in {total_time:.1f} seconds!")
        print(f"📊 Tasks: {self.completed_tasks}/{self.task_count}")
