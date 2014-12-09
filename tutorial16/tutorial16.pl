use strictures;

package tutorial16;

use lib '../arcsyn/framework';

use OpenGL::Debug qw(
  glutInit
  glutInitDisplayMode
  GLUT_DOUBLE
  GLUT_RGBA
  glutInitWindowSize
  glutInitWindowPosition
  glutCreateWindow
  glutDisplayFunc
  glClearColor
  glutMainLoop
  glClear
  GL_COLOR_BUFFER_BIT
  glutSwapBuffers

  GL_FLOAT
  glGenBuffersARB_p
  glBindBufferARB
  GL_ARRAY_BUFFER
  glBufferDataARB_s
  GL_STATIC_DRAW
  glEnableVertexAttribArrayARB
  glBindBufferARB
  glVertexAttribPointerARB_c
  GL_FLOAT
  GL_FALSE
  glDrawArrays
  GL_POINTS
  glDisableVertexAttribArrayARB

  GL_TRIANGLES

  GLUT_RGB
  glGetString
  GL_VERSION
  glCreateProgramObjectARB
  GL_VERTEX_SHADER
  GL_FRAGMENT_SHADER
  glCreateShaderObjectARB
  glShaderSourceARB_p
  glCompileShaderARB
  glGetShaderiv_p
  GL_COMPILE_STATUS
  glGetShaderInfoLog_p
  glAttachShader
  glLinkProgramARB
  glGetProgramiv_p
  GL_LINK_STATUS
  glGetInfoLogARB_p
  glValidateProgramARB
  GL_VALIDATE_STATUS
  glUseProgramObjectARB

  glutIdleFunc
  glGetUniformLocationARB_p
  glUniform1fARB

  glUniformMatrix4fvARB_s
  GL_TRUE

  glGenBuffersARB_p
  GL_ELEMENT_ARRAY_BUFFER
  glDrawElements_c
  GL_UNSIGNED_INT

  glutSpecialFunc

  glutGameModeString
  glutEnterGameMode
  glutPassiveMotionFunc
  glutKeyboardFunc
  glutLeaveMainLoop

  GL_TEXTURE0
  GL_CW
  GL_BACK
  GL_CULL_FACE
  GL_TEXTURE_2D
  glFrontFace
  glCullFace
  glEnable
  glUniform1iARB
);

use 5.010;

use PDL;
use PDL::Core 'howbig';
use IO::All -binary;
use lib '../Common';
use camera;
use pipeline;
use glut_backend 'GLUTKeyToOGLDEVKey';
use ogldev_texture;
use constant ASSERT        => 0;
use constant WINDOW_WIDTH  => 300;
use constant WINDOW_HEIGHT => 300;

my $VBO;
my $VBO_vertex_size;
my $VBO_tex_offset;
my $IBO;
my $gWVPLocation;
my $gSampler;
my $pTexture;
my $pGameCamera;

my $pVSFileName = "shader.vs";
my $pFSFileName = "shader.fs";

main();

sub RenderSceneCB {
    $pGameCamera->OnRender;

    glClear( GL_COLOR_BUFFER_BIT );

    state $Scale = 0;

    $Scale += 0.1;

    my $p = pipeline->new(
        Rotate    => [ 1, $Scale, 0 ],
        WorldPos  => [ 0, 0,      3 ],
        CameraPos => $pGameCamera->Pos,
        Target    => $pGameCamera->Target,
        Up        => $pGameCamera->Up,
        PerspectiveProj => { FOV => 60, Width => WINDOW_WIDTH, Height => WINDOW_HEIGHT, zNear => 1, zFar => 100 },
    );

    glUniformMatrix4fvARB_s( $gWVPLocation, 1, GL_TRUE, $p->GetWVPTrans->get_dataref );

    glEnableVertexAttribArrayARB( 0 );
    glEnableVertexAttribArrayARB( 1 );
    glBindBufferARB( GL_ARRAY_BUFFER, $VBO );
    glVertexAttribPointerARB_c( 0, 3, GL_FLOAT, GL_FALSE, $VBO_vertex_size, 0 );
    glVertexAttribPointerARB_c( 1, 2, GL_FLOAT, GL_FALSE, $VBO_vertex_size, $VBO_tex_offset );
    glBindBufferARB( GL_ELEMENT_ARRAY_BUFFER, $IBO );
    $pTexture->Bind( GL_TEXTURE0 );
    glDrawElements_c( GL_TRIANGLES, 12, GL_UNSIGNED_INT, 0 );

    glDisableVertexAttribArrayARB( 0 );
    glDisableVertexAttribArrayARB( 1 );

    glutSwapBuffers();

    return;
}

sub SpecialKeyboardCB {
    my ( $Key, $x, $y ) = @_;
    my $OgldevKey = GLUTKeyToOGLDEVKey( $Key );
    $pGameCamera->OnKeyboard( $OgldevKey );
    return;
}

sub KeyboardCB {
    my ( $Key, $x, $y ) = @_;
    glutLeaveMainLoop() if $Key == ord 'q';
}

sub PassiveMouseCB {
    my ( $x, $y ) = @_;
    $pGameCamera->OnMouse( $x, $y );
}

sub InitializeGlutCallbacks {
    my ( $VBO ) = @_;
    glutDisplayFunc( \&RenderSceneCB );
    glutIdleFunc( \&RenderSceneCB );
    glutSpecialFunc( \&SpecialKeyboardCB );
    glutPassiveMotionFunc( \&PassiveMouseCB );
    glutKeyboardFunc( \&KeyboardCB );
    return;
}

sub CreateVertexBuffer {
    my $v = pdl(    #
        [ -1, -1, 0.5773,   0,   0 ],
        [ 0,  -1, -1.15475, 0.5, 0 ],
        [ 1,  -1, 0.5773,   1,   0 ],
        [ 0,  1,  0,        0.5, 1 ],
    )->float;

    my $type_size = howbig( $v->get_datatype );
    $VBO_vertex_size = 5 * $type_size;
    $VBO_tex_offset  = 3 * $type_size;

    $VBO = glGenBuffersARB_p( 1 );
    glBindBufferARB( GL_ARRAY_BUFFER, $VBO );
    glBufferDataARB_s(
        GL_ARRAY_BUFFER,    #
        $v->nelem * $type_size,
        $v->get_dataref,
        GL_STATIC_DRAW,
    );

    return;
}

sub CreateIndexBuffer {
    my $Indices = pdl(      #
        0, 3, 1,
        1, 3, 2,
        2, 3, 0,
        0, 1, 2,
    )->long;

    $IBO = glGenBuffersARB_p( 1 );
    glBindBufferARB( GL_ELEMENT_ARRAY_BUFFER, $IBO );
    glBufferDataARB_s(
        GL_ELEMENT_ARRAY_BUFFER,    #
        $Indices->nelem * howbig( $Indices->get_datatype ),
        $Indices->get_dataref,
        GL_STATIC_DRAW,
    );

    return;
}

sub AddShader {
    my ( $ShaderProgram, $pShaderText, $ShaderType ) = @_;

    my $ShaderObj = glCreateShaderObjectARB( $ShaderType );

    if ( $ShaderObj == 0 ) {
        die sprintf "Error creating shader type %d\n", $ShaderType;
    }

    glShaderSourceARB_p( $ShaderObj, $pShaderText );
    glCompileShaderARB( $ShaderObj );
    my $success = glGetShaderiv_p( $ShaderObj, GL_COMPILE_STATUS );
    if ( !$success ) {
        my $InfoLog = glGetShaderInfoLog_p( $ShaderObj );
        die sprintf "Error compiling shader type %d: '%s'\n", $ShaderType, $InfoLog;
    }

    glAttachShader( $ShaderProgram, $ShaderObj );

    return;
}

sub CompileShaders {
    my $ShaderProgram = glCreateProgramObjectARB();

    if ( $ShaderProgram == 0 ) {
        die "Error creating shader program\n";
    }

    AddShader( $ShaderProgram, io( $pVSFileName )->all, GL_VERTEX_SHADER );
    AddShader( $ShaderProgram, io( $pFSFileName )->all, GL_FRAGMENT_SHADER );

    glLinkProgramARB( $ShaderProgram );
    my $success = glGetProgramiv_p( $ShaderProgram, GL_LINK_STATUS );
    if ( $success == 0 ) {
        my $ErrorLog = glGetInfoLogARB_p( $ShaderProgram );
        die "Error linking shader program: '%s'\n", $ErrorLog;
    }

    glValidateProgramARB( $ShaderProgram );
    $success = glGetProgramiv_p( $ShaderProgram, GL_VALIDATE_STATUS );
    if ( !$success ) {
        my $ErrorLog = glGetInfoLogARB_p( $ShaderProgram );
        die "Invalid shader program: '%s'\n", $ErrorLog;
    }

    glUseProgramObjectARB( $ShaderProgram );

    $gWVPLocation = glGetUniformLocationARB_p( $ShaderProgram, "gWVP" );
    die if ASSERT and $gWVPLocation == 0xFFFFFFFF;
    $gSampler = glGetUniformLocationARB_p( $ShaderProgram, "gSampler" );
    die if ASSERT and $gSampler == 0xFFFFFFFF;

    return;
}

sub main {
    glutInit();
    glutInitDisplayMode( GLUT_DOUBLE | GLUT_RGBA );
    glutInitWindowSize( WINDOW_WIDTH, WINDOW_HEIGHT );
    glutInitWindowPosition( 100, 100 );
    glutCreateWindow( "Tutorial 16" );

    #glutGameModeString( WINDOW_WIDTH . 'x' . WINDOW_HEIGHT );
    #glutEnterGameMode();

    InitializeGlutCallbacks();

    $pGameCamera = camera->new( windowWidth => WINDOW_WIDTH, windowHeight => WINDOW_HEIGHT );

    glClearColor( 0, 0, 0, 0 );
    glFrontFace( GL_CW );
    glCullFace( GL_BACK );
    glEnable( GL_CULL_FACE );

    CreateVertexBuffer();
    CreateIndexBuffer();

    CompileShaders();

    glUniform1iARB( $gSampler, 0 );

    $pTexture = Texture->new( TextureTarget => GL_TEXTURE_2D, FileName => "../Content/test.png" );

    if ( !$pTexture->Load() ) {
        return 1;
    }

    glutMainLoop();

    return;
}