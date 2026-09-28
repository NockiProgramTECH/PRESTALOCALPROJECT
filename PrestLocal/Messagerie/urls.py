from django.urls import path
from .views import inbox, conversation_detail, start_conversation, unread_message_count

app_name = 'Messagerie'

urlpatterns = [
    path('', inbox, name='inbox'),
    path('<int:pk>/', conversation_detail, name='conversation_detail'),
    path('start/<uuid:prestataire_id>/', start_conversation, name='start_conversation'),
    path('unread-count/', unread_message_count, name='unread_message_count'),
]
