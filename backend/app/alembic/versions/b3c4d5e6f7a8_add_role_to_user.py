"""add role to user

Revision ID: b3c4d5e6f7a8
Revises: 1a31ce608336, fe56fa70289e
Create Date: 2026-05-04 12:30:00.000000

"""
from alembic import op
import sqlalchemy as sa
import sqlmodel.sql.sqltypes


# revision identifiers, used by Alembic.
revision = 'b3c4d5e6f7a8'
down_revision = ('1a31ce608336', 'fe56fa70289e')
branch_labels = None
depends_on = None


def upgrade():
    op.add_column(
        'user',
        sa.Column('role', sqlmodel.sql.sqltypes.AutoString(), nullable=False, server_default='member'),
    )


def downgrade():
    op.drop_column('user', 'role')
