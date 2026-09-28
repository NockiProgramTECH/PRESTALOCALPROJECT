from rest_framework.permissions import BasePermission, SAFE_METHODS


class IsOwnerOrReadOnly(BasePermission):
    """
    Lecture pour tous.
    Modification uniquement par le propriétaire.
    """

    def has_object_permission(self, request, view, obj):

        # GET, HEAD, OPTIONS
        if request.method in SAFE_METHODS:
            return True

        # PUT PATCH DELETE
        return obj == request.user