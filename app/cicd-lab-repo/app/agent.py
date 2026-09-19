from google.adk.agents import Agent
from google.adk.apps import App
from google.adk.models import Gemini
from google.genai import types
from google.adk.tools import google_search  # The Google Search tool

import os
import google.auth

import logging
import google.cloud.logging
from google.cloud.logging.handlers import CloudLoggingHandler, setup_logging
from .callback_logging import log_query_to_model, log_model_response

cloud_logging_client = google.cloud.logging.Client()
handler = CloudLoggingHandler(cloud_logging_client, name="weather_assistant_logs")
setup_logging(handler)
logging.getLogger().setLevel(logging.INFO)

_, project_id = google.auth.default()
os.environ["GOOGLE_CLOUD_PROJECT"] = project_id
os.environ["GOOGLE_CLOUD_LOCATION"] = "global"
os.environ["GOOGLE_GENAI_USE_VERTEXAI"] = "True"
os.environ["GOOGLE_GENAI_USE_ENTERPRISE"] = "True"


root_agent = Agent(
    name="google_search_agent",
    description="Answer questions using Google Search.",
    model="gemini-3.5-flash",
    # instruction="You are an expert researcher. You stick to the facts.",
    instruction="""
    You are a specialized Weather Assistant. Your ONLY goal is to provide weather-related information, forecasts, and climate data.

    STRICT OPERATING RULES:
    1. TOPIC LIMITATION: You must only answer questions about the weather, temperature, precipitation, wind, or general climate conditions for a specific location.
    2. REFUSAL POLICY: If a user asks a question that is NOT related to the weather (e.g., history, math, news, general advice, or sports scores), you must politely decline and state: "I am a weather-specialized assistant and can only help with weather-related inquiries."
    3. TOOL USAGE: Use the Google Search tool exclusively to find accurate, up-to-date weather data. 
    4. NO GENERAL CHAT: Do not engage in general conversation or "small talk" that deviates from weather services.
    """,
    #before_model_callback=log_query_to_model,
    #after_model_callback=log_model_response,
    # tools: functions to enhance the model's capabilities.
    tools=[google_search]
)

app = App(
    root_agent=root_agent,
    name="app",
)