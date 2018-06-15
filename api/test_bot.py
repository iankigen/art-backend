import os

from slacker import Slacker


class SlackIntegrations(object):

    def __init__(self):
        self.notification = ""

    def slack_message(self, notification):
        slack = Slacker(os.getenv('SLACK_TOKEN'))

        # send message to channel
        message = input("Enter your message")
        slack.chat.post_message("#art-test", message)
