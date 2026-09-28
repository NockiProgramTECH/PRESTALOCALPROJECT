from django.urls import path
from .views import toggle_like, add_comment, feed_list

app_name = 'Feed'

urlpatterns = [
    path('like/<int:realisation_id>/', toggle_like, name='toggle_like'),
    path('comment/<int:realisation_id>/', add_comment, name='add_comment'),
    path('list/', feed_list, name='feed_list'),
]
